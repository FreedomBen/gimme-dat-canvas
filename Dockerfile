FROM canvas-release-2016-04-02.01

COPY canvas-lms /usr/src/app

USER root
RUN usermod -u 1002 docker
COPY setup-db.sh /usr/src/app
RUN chmod +x /usr/src/app/setup-db.sh
RUN chown -R docker:docker /usr/src/app

USER docker
ENV PATH $PATH:$GEM_HOME/bin

RUN bundle install
RUN npm install

RUN bundle exec rake canvas:compile_assets
