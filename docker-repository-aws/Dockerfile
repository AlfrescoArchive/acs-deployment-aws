# Fetch image based on alfresco-content-repository:6.2.0
# More infos about this image: https://github.com/Alfresco/acs-packaging/tree/master/docker-alfresco
FROM alfresco/alfresco-content-repository:6.2.0

USER root

# Set default docker_context. Will / Can be overriden with maven.
ARG resource_path=target

# Set default user information
ARG GROUPNAME=Alfresco
ARG USERNAME=alfresco

# Set default environment args
ARG TOMCAT_DIR=/usr/local/tomcat

# You need to run `mvn clean install` in the root of this project to update the following dependencies
# Copy the JDBC drivers for the database you are using to the lib/ directory.
COPY ${resource_path}/connector/* ${TOMCAT_DIR}/lib/

# Copy the amps from build context to the appropriate location for your application server
COPY ${resource_path}/amps ${TOMCAT_DIR}/amps

# Install amps on alfresco.war
RUN java -jar ${TOMCAT_DIR}/alfresco-mmt/alfresco-mmt*.jar install \
              ${TOMCAT_DIR}/amps ${TOMCAT_DIR}/webapps/alfresco -directory -nobackup -force

# The standard configuration is to have all Tomcat files owned by root with group GROUPNAME and whilst owner has read/write privileges,
# group only has restricted permissions and world has no permissions.
RUN chgrp -R ${GROUPNAME} ${TOMCAT_DIR}

USER ${USERNAME}