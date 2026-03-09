FROM node:20

WORKDIR /app

COPY apps/ui/package.json apps/ui/package-lock.json* ./
RUN npm install

COPY apps/ui ./

CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0"]
