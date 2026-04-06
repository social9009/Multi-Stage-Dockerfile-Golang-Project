FROM golang:1.21 AS builder
WORKDIR /app
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o hello main.go

FROM alpine:3.19
WORKDIR /app
COPY --from=builder /app/hello .
EXPOSE 8080
CMD ["./hello"] 
