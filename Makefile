release-jar:
	docker build -t scraper-release-jar .
	docker create --name scraper-release-jar scraper-release-jar
	docker cp scraper-release-jar:/scraper/scraper.jar ./scraper.jar
	docker rm scraper-release-jar
