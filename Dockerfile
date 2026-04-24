# Stage 1: Ambiente de Build do Flutter
FROM ubuntu:22.04 AS builder

# Instala as dependências necessárias do Linux
RUN apt-get update && apt-get install -y curl git unzip xz-utils zip libglu1-mesa

# Baixa o Flutter na mesma versão usada no ambiente local
RUN git clone https://github.com/flutter/flutter.git -b 3.41.4 /usr/local/flutter

# Adiciona o Flutter ao caminho (PATH) do sistema
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"
# ... (código anterior do Dockerfile) ...

WORKDIR /app
COPY . .

# Baixa os pacotes do projeto
RUN flutter pub get


# Compila a versão Web
RUN flutter build web

# ... (restante do código) ...
# Inicializa o Flutter
RUN flutter doctor -v

WORKDIR /app
COPY . .

# Baixa os pacotes do projeto e compila a versão Web
RUN flutter pub get
RUN flutter build web

# Stage 2: Servidor Nginx (Produção)
FROM nginx:alpine

# Copia os arquivos compilados da etapa anterior para a pasta do Nginx
COPY --from=builder /app/build/web /usr/share/nginx/html

# Expõe a porta 80
EXPOSE 80

# Inicia o servidor Nginx
CMD ["nginx", "-g", "daemon off;"]
