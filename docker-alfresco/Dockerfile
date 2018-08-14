# Fetch image based on Stable Image of ACS
FROM alfresco/alfresco-content-repository:6.0.0

# Copy the amps from build context to the appropriate location for your application server
COPY target/amps /usr/local/tomcat/amps

# Install amps on alfresco.war
RUN java -jar /usr/local/tomcat/alfresco-mmt/alfresco-mmt*.jar install \
              /usr/local/tomcat/amps /usr/local/tomcat/webapps/alfresco -directory -nobackup -force
