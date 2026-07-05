# Étape 1 : Construction (Builder)
FROM golang:latest AS builder
WORKDIR /app

# Téléchargement des dépendances
COPY go.mod go.sum ./
RUN go mod download

# Copie du code et compilation
COPY . .
# CGO_ENABLED=0 garantit un binaire statique parfait pour scratch/alpine
RUN CGO_ENABLED=0 GOOS=linux go build -o api-envirometrics main.go

# Étape 2 : Image finale ultra-légère
FROM alpine:latest
WORKDIR /root/

# Copier le binaire depuis le builder
COPY --from=builder /app/api-envirometrics .

# Exposer le port
EXPOSE 80

# Lancer l'API
CMD ["./api-envirometrics"]a
