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
    storage_client = storage.Client()
    
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
    
    # Install agent on each instance
    installed_count = 0
    failed_count = 0
    
    for instance_info in instances_to_process:
        try:
            print(f"\n[INSTALL] Starting installation for {instance_info['name']}")
            _install_agent(compute_client, storage_client, project_id, storage_bucket, 
                          instance_info['name'], instance_info['zone'])
            installed_count += 1
            print(f"[SUCCESS] Agent installed on {instance_info['name']}")
        except Exception as e:
            failed_count += 1
            print(f"[ERROR] Failed to install on {instance_info['name']}: {str(e)}")
    
    print(f"\n[FINAL SUMMARY]")
    print(f"Total scanned: {total_scanned}")
    print(f"Instances processed: {len(instances_to_process)}")
    print(f"Successfully installed: {installed_count}")
    print(f"Failed: {failed_count}")
    
    return {
        'status': 'success',
        'totalScanned': total_scanned,
        'instancesToProcess': len(instances_to_process),
        'installed': installed_count,
        'failed': failed_count,
        'instances': instances_to_process
    }, 200

def _get_zones(project_id):
    zones_client = compute_v1.ZonesClient()
    request = compute_v1.ListZonesRequest(project=project_id)
    return zones_client.list(request=request)

def _install_agent(compute_client, storage_client, project_id, bucket_name, instance_name, zone):
    """Install Trend Micro agent on a specific instance"""
    
    # Get instance details
    instance = compute_client.get(
        project=project_id,
        zone=zone,
        instance=instance_name
    )
    
    # Detect OS type
    is_windows = False
    for disk in instance.disks:
        if disk.licenses:
            for license_url in disk.licenses:
                if 'windows' in license_url.lower():
                    is_windows = True
                    break
    
    # Select script
    script_name = 'install-agent.ps1' if is_windows else 'install-agent.sh'
    print(f"[PLATFORM] Instance {instance_name}: {'Windows' if is_windows else 'Linux'}")
    print(f"[SCRIPT] Using: {script_name}")
    
    # Download script from GCS
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(script_name)
    
    if not blob.exists():
        raise Exception(f"Script {script_name} not found in bucket {bucket_name}")
    
    script_content = blob.download_as_text()
    print(f"[DOWNLOAD] Script downloaded: {len(script_content)} bytes")
    
    # Prepare metadata
    current_metadata = instance.metadata
    metadata_items = list(current_metadata.items) if current_metadata.items else []
    
    # Remove old startup script if exists
    metadata_items = [item for item in metadata_items 
                     if item.key not in ['startup-script', 'windows-startup-script-ps1']]
    
    # Add new startup script
    if is_windows:
        metadata_items.append(compute_v1.Items(key='windows-startup-script-ps1', value=script_content))
    else:
        metadata_items.append(compute_v1.Items(key='startup-script', value=script_content))
    
    # Update metadata
    metadata = compute_v1.Metadata(
        items=metadata_items,
        fingerprint=current_metadata.fingerprint
    )
    
    request = compute_v1.SetMetadataInstanceRequest(
        project=project_id,
        zone=zone,
        instance=instance_name,
        metadata_resource=metadata
    )
    
    operation = compute_client.set_metadata(request=request)
    print(f"[METADATA] Updated for {instance_name}")
    
    return True
