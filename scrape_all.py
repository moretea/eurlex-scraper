import os
for year in range(1973, 2022):
    os.system(f"bin/scraper scrape {year} PC")
