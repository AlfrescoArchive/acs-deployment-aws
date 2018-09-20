# Alfresco Enterprise Repository
# Copyright (C) 2005 - 2018 Alfresco Software Limited
# License rights for this program may be obtained from Alfresco Software, Ltd.
# pursuant to a written agreement and any use of this program without such an
# agreement is prohibited.

# Fetch image based on Stable Image of ACS
FROM alfresco/alfresco-content-repository:6.0.0

# You need to run `mvn clean install` in the root of this project to update the following dependencies
# Copy the JDBC drivers for the database you are using to the lib/ directory.
COPY target/connector/* /usr/local/tomcat/lib/
# Copy the amps from build context to the appropriate location for your application server
COPY target/amps /usr/local/tomcat/amps

# Install amps on alfresco.war
RUN java -jar /usr/local/tomcat/alfresco-mmt/alfresco-mmt*.jar install \
              /usr/local/tomcat/amps /usr/local/tomcat/webapps/alfresco -directory -nobackup -force
