ARG SPARK_VERSION=v3.3.1
FROM apache/spark-py:$SPARK_VERSION


USER root
WORKDIR /opt

# install wget unzip
RUN \
apt-get update && \
apt-get install wget unzip -y && \
rm -rf /var/lib/apt/lists/*

COPY requirements.txt /opt
RUN pip3 install -r /opt/requirements.txt

# add new non-root user to root group , allows access to spark jars
RUN useradd -g root appuser

# grant permissions to appuser 
RUN chown -R appuser /opt

# get relevant jar files
#delta
ADD --chown=appuser:root https://repo1.maven.org/maven2/io/delta/delta-contribs_2.12/2.2.0/delta-contribs_2.12-2.2.0.jar $SPARK_HOME/jars
ADD --chown=appuser:root https://repo1.maven.org/maven2/io/delta/delta-core_2.12/2.2.0/delta-core_2.12-2.2.0.jar $SPARK_HOME/jars
ADD --chown=appuser:root https://repo1.maven.org/maven2/io/delta/delta-storage/2.2.0/delta-storage-2.2.0.jar $SPARK_HOME/jars
ADD --chown=appuser:root https://repo1.maven.org/maven2/io/delta/delta-storage-s3-dynamodb/2.2.0/delta-storage-s3-dynamodb-2.2.0.jar $SPARK_HOME/jars
# #ecs
ADD --chown=appuser:root https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.3.1/hadoop-aws-3.3.1.jar $SPARK_HOME/jars
ADD --chown=appuser:root https://repo1.maven.org/maven2/com/amazonaws/aws-java-sdk-bundle/1.11.901/aws-java-sdk-bundle-1.11.901.jar $SPARK_HOME/jars
# Add the GCS connectors
ADD --chown=appuser:root https://repo1.maven.org/maven2/com/google/cloud/bigdataoss/gcs-connector/hadoop3-2.2.12/gcs-connector-hadoop3-2.2.12-shaded.jar $SPARK_HOME/jars
# add spark-excel jar
# ADD --chown=appuser:root https://repo1.maven.org/maven2/com/crealytics/spark-excel_2.12/3.3.1_0.18.5/spark-excel_2.12-3.3.1_0.18.5.jar $SPARK_HOME/jars

# run image as appuser
USER appuser
# copy src files 
COPY src /opt/src

ENTRYPOINT [ "/opt/entrypoint.sh" ]
