def ECR = ''

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
        credentials credentialType: 'com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl', defaultValue: '', name: 'aws_iam', required: true
        string 'key'
        string 'bucket'
        string 'vpc_id'
    }
    stages {
        stage('Create infrastracture') {
            steps{
                withCredentials([usernamePassword(credentialsId: params.aws_iam, passwordVariable: 'AWS_SECRET_ACCESS_KEY', usernameVariable: 'AWS_ACCESS_KEY_ID')]) {
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
                sh 'docker build .'
                unstash 'ecr'
                sh 'cat ecr.txt'
            }
        }
    }
}