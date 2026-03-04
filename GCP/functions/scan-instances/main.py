import os
import json
from google.cloud import compute_v1
from google.cloud import storage
import functions_framework

@functions_framework.http
def scan_instances(request):
    project_id = os.environ.get('PROJECT_ID')
    storage_bucket = os.environ.get('STORAGE_BUCKET')
    tag_filter = os.environ.get('TAG_FILTER', 'NONE')
    
    print(f"[START] Scanning GCE instances in project: {project_id}")
    print(f"[CONFIG] Storage bucket: {storage_bucket}")
    print(f"[CONFIG] Tag filter: {tag_filter}")
    
    compute_client = compute_v1.InstancesClient()
    
    required_labels = {}
    if tag_filter != 'NONE':
        try:
            for pair in tag_filter.split(';'):
                key, value = pair.split(':', 1)
                required_labels[key.strip()] = value.strip()
            print(f"[INFO] Required labels: {json.dumps(required_labels)}")
        except ValueError:
            return {'error': 'Invalid tag format. Use key:value or key:value;key2:value2'}, 400
    else:
        print("[INFO] No label filtering (NONE)")
    
    instances_to_process = []
    total_scanned = 0
    
    for zone in _get_zones(project_id):
        zone_name = zone.name
        print(f"[SCAN] Checking zone: {zone_name}")
        
        request_obj = compute_v1.ListInstancesRequest(
            project=project_id,
            zone=zone_name
        )
        
        instances = compute_client.list(request=request_obj)
        
        for instance in instances:
            total_scanned += 1
            
            if instance.status != 'RUNNING':
                continue
            
            instance_labels = instance.labels or {}
            
            if required_labels:
                label_match = all(
                    instance_labels.get(k) == v 
                    for k, v in required_labels.items()
                )
                if not label_match:
                    print(f"[SKIP] Instance {instance.name} - labels don't match")
                    continue
            
            instances_to_process.append({
                'name': instance.name,
                'zone': zone_name,
                'id': instance.id
            })
            print(f"✓ Instance: {instance.name} (zone: {zone_name})")
    
    print(f"\n[SUMMARY] Total scanned: {total_scanned}")
    print(f"[SUMMARY] Instances to process: {len(instances_to_process)}")
    
    _trigger_installations(project_id, storage_bucket, instances_to_process)
    
    return {
        'totalScanned': total_scanned,
        'instancesToProcess': len(instances_to_process),
        'instances': instances_to_process
    }, 200

def _get_zones(project_id):
    zones_client = compute_v1.ZonesClient()
    request = compute_v1.ListZonesRequest(project=project_id)
    return zones_client.list(request=request)

def _trigger_installations(project_id, bucket, instances):
    from google.cloud import pubsub_v1
    
    publisher = pubsub_v1.PublisherClient()
    topic_path = publisher.topic_path(project_id, 'trendmicro-agent-install')
    
    for instance in instances:
        message_data = json.dumps(instance).encode('utf-8')
        future = publisher.publish(topic_path, message_data)
        print(f"[PUBSUB] Published message for instance: {instance['name']}")
