pipeline {
    agent {
        label 'jenkins-agent'
    }
    tools {
        terraform 'terraform-linux'
        git 'Default'
    }
    stages {
        stage('Create infrastracture') {
            steps{
                sh 'mkdir ~/.ssh'
                sh 'ssh-keyscan github.com >> ~/.ssh/known_hosts'
                dir('terraform-state') {
                    git branch: 'main', changelog: false, credentialsId: params.state_repo_credentials, poll: false, url: params.state_repo // Private repo with statefile
                }
                sh 'terraform init'
                withCredentials([usernamePassword(credentialsId: params.aws_iam, passwordVariable: 'AWS_SECRET_ACCESS_KEY', usernameVariable: 'AWS_ACCESS_KEY_ID')]) {
                    sh 'terraform apply -auto-approve -var region="${region}" -var profile="${profile}" -state=terraform-state/terraform.tfstate'
                }
                dir('terraform-state') {
                    sh 'git config user.email "jenkins"@jenkins.jenkins'
                    sh 'git config user.name "Jenkins"'
                    sh 'git add .'
                    withCredentials([sshUserPrivateKey(credentialsId: params.state_repo_credentials, keyFileVariable: 'key')]) {
                        sh 'git commit -m "Updated statefile"'
                        sh 'GIT_SSH_COMMAND="ssh -i $key"'
                        sh 'git push -u origin main'
                    }
                }
            }
        }
    }
}