pipeline {
    agent {
        label 'jenkins-agent'
    }
    tools {
        terraform 'terraform-linux'
        git 'Default'
    }
    parameters {
        string 'AWS_REGION'
        credentials credentialType: 'com.cloudbees.jenkins.plugins.awscredentials.AWSCredentialsImpl', defaultValue: '', name: 'aws_iam', required: true
        string 'bucket'
        string 'key'
        string 'vpc_id'
    }
    stages {
        stage('Create infrastracture') {
            steps{
                withAWS(credentials: params.aws_iam, region: params.AWS_REGION) {
                    sh 'terraform init -backend-config="bucket=${bucket}" -backend-config="key=${key}"'
                    sh 'terraform apply -auto-approve -var vpc_id=${vpc_id}'
                    sh 'terraform output -raw repository_url > ecr.txt'
                }
                stash includes: 'ecr.txt', name: 'ecr'
            }
        }
        stage('Build jenkins') {
            agent {
                label 'docker-agent'
            }
            steps{
                unstash 'ecr'
                withAWS(credentials: params.aws_iam, region: params.AWS_REGION) {
                    sh "set +x && "+ecrLogin()
                }
                sh 'docker build . -t `cat ecr.txt`:latest'
                sh 'docker push `cat ecr.txt`:latest'
            }
        }
    }
}