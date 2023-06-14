FROM jenkins/jenkins:2.401.1
RUN jenkins-plugin-cli --plugins "blueocean docker-plugin configuration-as-code"
ENV CASC_JENKINS_CONFIG /etc/jenkins.yaml