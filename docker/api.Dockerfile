# Build stage
FROM maven:3.9-eclipse-temurin-17-alpine AS build
WORKDIR /app
COPY api/pom.xml api/mvnw api/mvnw.cmd ./
COPY api/.mvn ./.mvn
COPY api/src ./src
RUN chmod +x mvnw && ./mvnw -q -DskipTests package

# Runtime
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
# ffmpeg comprime os vídeos dos exercícios (720p, até 60 s) antes de guardar.
RUN apk add --no-cache ffmpeg
COPY --from=build /app/target/academia-api-*.jar app.jar
RUN mkdir -p /app/uploads
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
