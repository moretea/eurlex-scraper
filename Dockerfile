FROM jruby:1.7
WORKDIR /scraper

COPY Gemfile* /scraper/
RUN bundle

COPY bin/* /scraper/bin/
COPY lib/* /scraper/lib/
RUN bundle exec warble compiled runnable jar
CMD bundle exec jruby bin/scraper
