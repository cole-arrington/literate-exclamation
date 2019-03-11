FROM python:alpine3.9

# Create copy layer for requirements
COPY requirements.txt /requirements.txt

# Install dependencies
RUN pip install -r requirements.txt

# Create copy layer for app code
ARG app_dir
COPY $app_dir /app
WORKDIR /app

# Start application
ENV app_file="$app_file"
CMD ["sh", "-c", "python $app_file"]