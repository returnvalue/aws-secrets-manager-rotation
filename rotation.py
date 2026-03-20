import boto3
import json
import os

def handler(event, context):
    arn = event['SecretId']
    token = event['ClientRequestToken']
    step = event['Step']

    service_client = boto3.client('secretsmanager')

    if step == "createSecret":
        create_secret(service_client, arn, token)
    elif step == "setSecret":
        set_secret(service_client, arn, token)
    elif step == "testSecret":
        test_secret(service_client, arn, token)
    elif step == "finishSecret":
        finish_secret(service_client, arn, token)
    else:
        raise ValueError("Invalid step parameter")

def create_secret(service_client, arn, token):
    # Generate a new random password and store it as a pending version
    try:
        service_client.get_secret_value(SecretId=arn, VersionId=token, VersionStage="AWSPENDING")
        print(f"createSecret: Successfully retrieved secret for {arn}")
    except service_client.exceptions.ResourceNotFoundException:
        # Get the current secret value to maintain the same username
        current_dict = json.loads(service_client.get_secret_value(SecretId=arn, VersionStage="AWSCURRENT")['SecretString'])
        
        # Generate new password
        new_password = service_client.get_random_password(ExcludeCharacters='/@"')['RandomPassword']
        current_dict['password'] = new_password
        
        service_client.put_secret_value(SecretId=arn, ClientRequestToken=token, SecretString=jsonencode(current_dict), VersionStages=['AWSPENDING'])
        print(f"createSecret: Successfully put secret for {arn}")

def set_secret(service_client, arn, token):
    # In a real RDS scenario, this is where you'd update the database with the new password
    print(f"setSecret: (Conceptual) Updating database with new password for {arn}")

def test_secret(service_client, arn, token):
    # In a real RDS scenario, this is where you'd verify the new password works
    print(f"testSecret: (Conceptual) Verifying new password works for {arn}")

def finish_secret(service_client, arn, token):
    # Move the AWSCURRENT label to the new version
    metadata = service_client.describe_secret(SecretId=arn)
    current_version = None
    for version in metadata['VersionIdsToStages']:
        if "AWSCURRENT" in metadata['VersionIdsToStages'][version]:
            current_version = version
            break
    
    service_client.update_secret_version_stage(SecretId=arn, VersionStage="AWSCURRENT", MoveToVersionId=token, RemoveFromVersionId=current_version)
    print(f"finishSecret: Successfully set AWSCURRENT to version {token} for {arn}")
