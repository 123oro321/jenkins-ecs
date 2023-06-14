# What does it do
The project provides docker-compose file to create a Jenkins server, connected to Docker in Docker container through internal network over ssl.  
It configures cloud template with the image `jenkins/agent` and the label `jenkins-agent`

It will create 2 volumes:  
`jenkins-data`: for all persistent Jenkins data like system configuration, pipelines, artifact and etc.  
`jenkins-docker-certs`: for Docker in Docker SSL certifications.


# How to use
To use just `cd` into the project and run `docker-compose up -d`.

Feel free to customize [jenkins.yaml](jenkins.yaml) to configure your Jenkins as you see fit.