FROM ruby:3.3.0
ARG BUILD_TAG=local
WORKDIR /rails

ENV DEBIAN_FRONTEND noninteractive

# Set production environment
ENV RAILS_LOG_TO_STDOUT="1" \
    RAILS_SERVE_STATIC_FILES="true" \
    RAILS_ENV="production" \
    BUNDLE_WITHOUT="development:test" \
    BUNDLE_DEPLOYMENT="1" \
    BUILD_TAG=$BUILD_TAG

# Add dependencies necessary to install nodejs.
# From: https://github.com/nodesource/distributions#debian-and-ubuntu-based-distributions
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      ca-certificates \
      curl \
      gnupg

ARG NODE_MAJOR=20
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_MAJOR}.x | bash && \
    apt-get install -y nodejs

# Enable 'corepack' feature that lets NPM download the package manager on-the-fly as required.
RUN corepack enable

# Install native dependencies for Ruby:
# libvips = image processing for Rails ActiveStorage attachments
# libssl-dev = bindings for the native extensions of Ruby SSL gem
# libyaml-dev = bindings for the native extensions of Ruby psych gem
# tzdata = Timezone information for Rails ActiveSupport
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      software-properties-common \
      git \
      pkg-config \
      libvips \
      libssl-dev \
      libyaml-dev \
      tzdata

# Install fonts for rendering PDFs (mostly competition summary PDFs)
# dejavu = Hebrew, Arabic, Greek
# unfonts-core = Korean
# wqy-modern = Chinese
# ipafont = Japanese
# lmodern = Random accents and special symbols for Latin script
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      fonts-dejavu \
      fonts-unfonts-core \
      fonts-wqy-microhei \
      fonts-ipafont \
      fonts-lmodern

# Regenerate the font cache so WkHtmltopdf can find them
# per https://dalibornasevic.com/posts/76-figuring-out-missing-fonts-for-wkhtmltopdf
RUN fc-cache -f -v

# Use the MariaDB package sources via https://mariadb.com/kb/en/mariadb-package-repository-setup-and-usage/
# because the Ruby base image runs on Debian 12, which provides an older MariaDB version that suffers from a
# mysqldump bug in conjunction with MySQL 8.0 servers: https://jira.mariadb.org/browse/MDEV-31836
# (the issue was fixed in 10.11.5 but Debian only provides 10.11.4 so we need to override)
RUN curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | bash -s -- --mariadb-server-version="mariadb-10.11" && \
    apt-get install -y mariadb-client && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN gem update --system && gem install bundler
RUN bundle install && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# Install node dependencies
COPY package.json yarn.lock .yarnrc.yml ./
RUN yarn install --immutable

# Copy built artifacts: gems, application
COPY . .

# Run and own only the runtime files as a non-root user for security
RUN useradd rails --create-home --shell /bin/bash && \
    chown -R rails:rails vendor db log tmp public app pids .yarn
USER rails:rails

# Entrypoint prepares database and starts app on 0.0.0.0:3000 by default,
# but can also take a rails command, like "console" or "runner" to start instead.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

EXPOSE 3000
CMD ["./bin/bundle", "exec", "unicorn", "-c", "/rails/config/unicorn.rb"]
