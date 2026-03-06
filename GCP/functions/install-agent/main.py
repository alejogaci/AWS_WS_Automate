import os
import json
import base64
from google.cloud import compute_v1
from google.cloud import storage
import functions_framework

@functions_framework.cloud_event
def install_agent(cloud_event):
    project_id = os.environ.get('PROJECT_ID')
    storage_bucket = os.environ.get('STORAGE_BUCKET')
    
    event_data = cloud_event.data
    
    if 'protoPayload' in event_data:
        resource_name = event_data['protoPayload']['resourceName']
        parts = resource_name.split('/')
        zone = parts[parts.index('zones') + 1]
        instance_name = parts[-1]
    else:
        print("[ERROR] Cannot extract instance information from event")
        return
    
    print(f"[START] Installing agent on instance: {instance_name}")
    print(f"[INFO] Zone: {zone}")
    print(f"[INFO] Project: {project_id}")
    
    compute_client = compute_v1.InstancesClient()
    storage_client = storage.Client()
    
    try:
        instance = compute_client.get(
            project=project_id,
            zone=zone,
            instance=instance_name
        )
        
        print(f"[INSTANCE] Status: {instance.status}")
        print(f"[INSTANCE] Machine type: {instance.machine_type}")
        
        is_windows = any('windows' in disk.licenses[0].lower() for disk in instance.disks if disk.licenses)
        
        # Find script in bucket
        bucket = storage_client.bucket(storage_bucket)
        
        if is_windows:
            # Find any .ps1 file
            blobs = bucket.list_blobs()
            script_name = None
            for blob in blobs:
                if blob.name.endswith('.ps1'):
                    script_name = blob.name
                    break
            
            if not script_name:
                print(f"[ERROR] No PowerShell script (.ps1) found in bucket {storage_bucket}")
                return
            
            metadata_key = 'windows-startup-script-ps1'
            print("[PLATFORM] Detected: Windows")
            print(f"[SCRIPT] Found: {script_name}")
        else:
            # Find any .sh file
            blobs = bucket.list_blobs()
            script_name = None
            for blob in blobs:
                if blob.name.endswith('.sh'):
                    script_name = blob.name
                    break
            
            if not script_name:
                print(f"[ERROR] No shell script (.sh) found in bucket {storage_bucket}")
                return
            
            metadata_key = 'startup-script'
            print("[PLATFORM] Detected: Linux")
            print(f"[SCRIPT] Found: {script_name}")
        
        blob = bucket.blob(script_name)
        script_content = blob.download_as_text()
        print(f"[SCRIPT] Downloaded: {script_name}")
        print(f"[SCRIPT] Size: {len(script_content)} bytes")
        
        # Get current metadata
        current_metadata = instance.metadata
        metadata_items = list(current_metadata.items) if current_metadata.items else []
        
        # Remove old startup scripts
        metadata_items = [item for item in metadata_items 
                         if item.key not in ['startup-script', 'windows-startup-script-ps1']]
        
        # Add new startup script
        metadata_items.append(
            compute_v1.Items(
                key=metadata_key,
                value=script_content
            )
        )
        
        request = compute_v1.SetMetadataInstanceRequest(
            project=project_id,
            zone=zone,
            instance=instance_name,
            metadata_resource=compute_v1.Metadata(
                items=metadata_items,
                fingerprint=current_metadata.fingerprint
            )
        )
        
        operation = compute_client.set_metadata(request=request)
        print(f"[SUCCESS] Metadata set for instance {instance_name}")
        print(f"[COMPLETED] Agent installation script deployed")
        
    except Exception as e:
        print(f"[ERROR] Failed to install agent: {str(e)}")
        raise

