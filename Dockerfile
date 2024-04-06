# Use the official Python image as base
FROM python:3.8

#Set environment variables
ENV APP_PORT=5153
ENV DB_USERNAME=myuser
ENV DB_PASSWORD=mypassword
ENV DB_HOST=127.0.0.1
ENV DB_PORT=5432
ENV DB_NAME=postgres

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

CMD ["python", "/app/analyticsapp.py"]