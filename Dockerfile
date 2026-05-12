# Start from your Golden Image
FROM my-r-golden

USER root
# Install Shiny and RSQLite
RUN apt-get update && apt-get install -y --no-install-recommends \
    r-cran-shiny \
    r-cran-rsqlite \
    && rm -rf /var/lib/apt/lists/*

# Copy your app code into the container
RUN mkdir /app
COPY . /app
WORKDIR /app

EXPOSE 3838

# Run the app
CMD ["R", "-e", "shiny::runApp('/app', host = '0.0.0.0', port = 3838)"]
