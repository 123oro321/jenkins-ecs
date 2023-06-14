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
                sh 'ls -l -a .aws'
                sh 'mkdir ~/.ssh'
                sh 'ssh-keyscan github.com >> ~/.ssh/known_hosts'
                dir('terraform-state') {
                    git branch: 'main', changelog: false, credentialsId: params.state_repo_credentials, poll: false, url: params.state_repo // Private repo with statefile
                }
                sh 'terraform init'
                sh 'terraform apply -auto-approve -var region="${region}" -var profile="${profile}" -state=terraform-state/terraform.tfstate'
                dir('terraform-state') {
                    sh 'git add .'
                    sh 'git commit -m "Updated statefile"'
                    sh 'git push'
                }
            }
        }
    }
}