FROM python:alpine3.9

# Create copy layer for requirements
COPY requirements.txt /requirements.txt

# Install dependencies
RUN pip install -r requirements.txt

# Create copy layer for app code
COPY . /app
WORKDIR /app

# Start application
ENTRYPOINT ["python"]
CMD ["hardware.py"]