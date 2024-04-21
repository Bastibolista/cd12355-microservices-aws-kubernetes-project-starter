# Use the official Python image as base
FROM python:3.8

# Set the working directory in the container
WORKDIR /app

# Copy content of the directory analytics
COPY /analytics /app/analytics

# Copy content of the directory db
COPY /db /app/db

# Install any needed dependencies specified in requirements.txt
RUN pip install --upgrade pip && pip install -r /app/analytics/requirements.txt

# Expose port 5153 to the outside world
EXPOSE 5153

CMD ["python", "/app/analytics/app.py"]