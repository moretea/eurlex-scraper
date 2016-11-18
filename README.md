# EURLEX scraper & processor
This repo contains two tools to scrape EURLEX and process publications:

- A scraper progam that fetches the HTML from EURLEX, taking into account certain restrictions on
  which kind of documents should be attempted to scrape.
- A processor program, that processes the HTML and writes a CSV file.

Each EURLEX publication has a unique identifier, the CELEX number.
It consists of three components: `3YYYYLNNNN`, where `3` is fixed, `YYYY` denotes the year, `L` is
a "letter", indicating what kind of publication it is, and `NNNN` is a unique number identifiying
the publication within a year and kind of publication.

## Scraper

The scraper can be invoked with the following commands:

    java -jar scraper.jar scrape <YEAR> <OPTIONAL OVERRIDE LETTERS> <OPTIONAL START NUMBER AND  END NUMBER>

Only the year must be provided, optionally multiple letters can be added, separated by spaces.
It is also possible to limit the range of numbers, note that both a start and end number must be
provided in that case.

If no overriding letters are provided, the default letters `D`, `L`, `R` and `M` are scraped.

### Storage of data
The scraped data is stored in the `data` directory, in the current directory.
This `data` directory will contain folders for each year.
Each year directory contains two files, `found.txt` and `not-found.txt`, storing state on
which CELEX numbers have been scraped, and which could not be found respectively.

### Handling of non existing documents
When a CELEX number does not exist, the HTTP server will return a `404 not found` status.
In this case, we mark the document as non existing, and append the number to the `not-found.txt`
file.
NOTE: Therefore removing or editing this file makes it possible to re-try non-existing documents
for some given year / range.
Removing the `found.txt` will result in having to re-scrape the entire year and is not recommended;
if you want to re-scrape a complete year, you should also remove the html directory to save disk
space.

### Example invocations

- Scrape all default letters in 2014:
  ```
    java -jar scrape.jar scrape 2014
  ```
- Scrape only R and M letters for 2014, check all document numbers:
  ```
    java -jar scraper.jar scrape 2014 R M
  ```
- Scrape only L and D letters for 2014, check a custom range:
  ```
    java -jar scraper.jar scrape 2014 L D 20 200
  ```

### Behavior at failure conditions
Two types of failures are attempted are distinguished. Timeouts to fetch the HTML, and any other
error raised during the process. The latter are very unlikey to happen.

When a request to fetch a page does not return a result within 60 seconds, it it scheduled to be
attempted again after 60 seconds.
If any other (not yet-tried) document can be scraped, they are, until the 60 secons have passed.
This implies that retries-after-failure have a higher priority than attempting to scrape not-yet
attempted documents.
The reason for this is that the alternative is to queue all failures to the end of the run, after
which you'd have to attempt to scrape, and wait again for some time to retry if they fail again.
This easily results in significant longer run time.

Documents that trigger a timeout are attempted at most ten times. Documents that trigger an
exception are attempted at maximum three times.

Note: So far, I have not encountered any document that could not be scraped in the end.
In the worst case, the program can be run multiple times after each other, since it would
rember it's progress.
If the processor complains about some document not being scraped, a work around could be to add the
CELEX numer to the `not-found.txt` file.

## Processing the scraped data
Processing the scraped data is done with the `processor` command.
It accepts exactly the same filters as the `scrape` command, except that an output file name must
be specified.

    java -jar scraper.jar process <YEAR> <OPTIONAL OVERRIDE LETTERS> <OPTIONAL START NUMBER AND  END NUMBER> <REQUIRED OUTPUT FILE NAME>

Note that this requires quite some memory, and can cause a out-of-memory crash. This is caused
by the conservative amount of memory that a java process can use by default (256mb).
This can be solved by providing a JVM option to increase this limit.
The following example sets this maximum to 4GB of RAM.

    java -Xmx4G -jar scraper.jar process ....

## Development
- Standard (j)ruby practises, bundler, warbler, etc.

### Cutting a jar
Done via Makefile. This starts to build a container with a specific version of jruby.
Bundler is run in the container, and finally it cuts a jar using warble.
When control is returned to the Makefile, it extracts the jar from the build docker container image.
(unfortunately, there is no better way than to create a container, then copy the jar, and kill
that container).

## License
Released under the [AGPL-3.0 license](https://www.gnu.org/licenses/agpl-3.0.html).
