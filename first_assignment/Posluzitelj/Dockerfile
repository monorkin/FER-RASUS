FROM ruby:2.5-alpine
RUN apk add --no-cache \
    build-base \
    gcc \
    abuild \
    binutils \
    binutils-doc \
    gcc-doc \
    sqlite \
    sqlite-dev \
    sqlite-libs \
    less \
    bash
WORKDIR /app
COPY . .
RUN gem install rack
RUN gem install puma
RUN gem install roda
RUN gem install sequel
RUN gem install sqlite3
EXPOSE 8080
CMD ruby ./server.rb
