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
    }
    stages {
        stage('Create infrastracture') {
            steps{
                withCredentials([usernamePassword(credentialsId: params.aws_iam, passwordVariable: 'AWS_SECRET_ACCESS_KEY', usernameVariable: 'AWS_ACCESS_KEY_ID')]) {
                    sh 'terraform init -backend-config="bucket=${params.bucket}" -backend-config="key=${params.key}"'
                    sh 'terraform apply -auto-approve'
                    //sh 'terraform destroy -auto-approve'
                }
            }
        }
    }
}