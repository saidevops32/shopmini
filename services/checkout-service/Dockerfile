# ---- stage 1: build the jar (tests run in CI, not here) ----
FROM maven:3.9-eclipse-temurin-21@sha256:99e61abcff91a9b1333463bd8451fb18495d6eba9250ac66a338b518f8278320 AS build
WORKDIR /build
COPY pom.xml .
RUN mvn -B -q dependency:go-offline
COPY src ./src
RUN mvn -B -q package -DskipTests

# ---- stage 2: JRE only, non-root, no Maven, no JDK ----
FROM eclipse-temurin:21-jre-alpine@sha256:82cf3d9ccbe1ed46252008d51b2f2329e6b9e8a2f4394c4bebefc3ea7f4b1372
LABEL org.opencontainers.image.source="https://github.com/saidevops32/shopmini" \
      org.opencontainers.image.title="checkout-service" \
      org.opencontainers.image.licenses="MIT"
# stopgap: patch libexpat until the base image is rebuilt; remove once trivy image is clean without it
RUN apk upgrade --no-cache libexpat
RUN addgroup -S -g 10001 app && adduser -S -u 10001 -G app app
WORKDIR /app
COPY --from=build --chown=10001:10001 /build/target/checkout-service.jar app.jar
USER 10001:10001
ENV JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75 -XX:+ExitOnOutOfMemoryError"
EXPOSE 8080
# exec form: java is PID 1 and receives SIGTERM (Spring graceful shutdown)
ENTRYPOINT ["java", "-jar", "app.jar"]
