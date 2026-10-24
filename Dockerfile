
# Stage 1: Runtime for Spring PetClinic
FROM eclipse-temurin:21-jre

LABEL maintainer="DevOps Team"
LABEL description="Spring PetClinic Application"
LABEL version="1.0"

# Create a non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Install curl for health checks
RUN apt-get update && apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy the JAR already built by Jenkins
COPY target/spring-petclinic-*.jar ./app.jar

# Set ownership
RUN chown appuser:appuser /app/app.jar

# Run as a non-root user
USER appuser

# Application port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health/liveness || exit 1

# JVM options
ENV JAVA_OPTS="-XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+ParallelRefProcEnabled -Xms256m -Xmx512m"

# Start the application
ENTRYPOINT ["sh", "-c", "exec java $JAVA_OPTS -jar app.jar"]
