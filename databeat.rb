require 'httparty'
require 'sqlite3'
require 'pry'
# Function to create the SQLite database and the tables
def create_database
  db = SQLite3::Database.new('movies.db')

  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS popular_movies (
      id INTEGER PRIMARY KEY,
      title TEXT,
      overview TEXT,
      release_date TEXT,
      popularity REAL
    );
  SQL
  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS reviews_movies (
      movie_id INTEGER,
      author TEXT,
      content TEXT,
      author_name TEXT, 
      author_username TEXT,
      author_avatar_path TEXT, 
      author_rating REAL,
      FOREIGN KEY (movie_id) REFERENCES popular_movies(id)
    );
  SQL

  db.execute <<-SQL
    CREATE TABLE IF NOT EXISTS cc_movies (
      movie_id INTEGER,
      name TEXT,
      department TEXT,
      FOREIGN KEY (movie_id) REFERENCES popular_movies (id)
    );
  SQL

  db
end

# fetch popular movies and store them in the database
def fetch_popular_movies(page, db)
  base_url = 'https://api.themoviedb.org/3'
  api_key = '<auth_key>' # Replace with your TMDB API key

  response = HTTParty.get("#{base_url}/movie/popular", query: {
    api_key: api_key,
    page: page
  })

  if response.code == 200
    movies = JSON.parse(response.body)['results']

    movies.each do |movie|
      id = movie['id']
      title = movie['title']
      overview = movie['overview']
      release_date = movie['release_date']
      popularity = movie['popularity']

      db.execute('INSERT INTO popular_movies (id, title, overview, release_date, popularity) VALUES (?, ?, ?, ?, ?)',
                 [id, title, overview, release_date, popularity])

      fetch_movie_reviews(id, db)
      fetch_movie_cast_and_crew(id,db)
    end
  else
    puts "Failed to fetch popular movies for page #{page}."
  end
end

# Function to fetch reviews for a movie and store them in the database
def fetch_movie_reviews(movie_id, db)

  base_url = 'https://api.themoviedb.org/3'
  api_key = '<auth_key>' # Replace with your TMDB API key

  response = HTTParty.get("#{base_url}/movie/#{movie_id}/reviews", query: {
    api_key: api_key,
    page: 1 # Fetch only the first page of reviews
  })

  if response.code == 200
    reviews = JSON.parse(response.body)['results']
    reviews.each do |review|


      # movie_id INTEGER,
      # author TEXT,
      # content TEXT,
      # author_name TEXT, 
      # author_username TEXT,
      # author_avatar_path TEXT, 
      # author_rating REAL,

      author = review['author']
      content = review['content']
      author_name = review['author_details']['name']
      author_username = review['author_details']['username']
      author_avatar_path = review['author_details']['avatar_path']
      author_rating = review['author_details']['rating']

      db.execute('INSERT INTO reviews_movies (movie_id, author, content, author_name,  author_username, author_avatar_path, author_rating  ) VALUES ( ?, ?, ?, ?, ?, ?, ?)',[movie_id, author, content, author_name, author_username, author_avatar_path, author_rating ])
    end
  else
    puts "Failed to fetch reviews for movie with ID #{movie_id}."
  end
end


#cast _crew

def fetch_movie_cast_and_crew(movie_id, db)
  base_url = 'https://api.themoviedb.org/3'
  api_key = '<auth_key>' # Replace with your TMDB API key

  response = HTTParty.get("#{base_url}/movie/#{movie_id}/credits", query: {
    api_key: api_key,
    page: 1
  })
  if response.code == 200
    cast_and_crew = JSON.parse(response.body)
    cast = cast_and_crew['cast']
    crew = cast_and_crew['crew']

    cast.each do |member|
      name = member['name']
      department = 'Cast'

      db.execute('INSERT INTO cc_movies (movie_id, name, department) VALUES ( ?, ?, ?)',
                 [ movie_id, name, department])
    end

    crew.each do |member|
      name = member['name']
      department = member['department']

      db.execute('INSERT INTO cc_movies (movie_id, name, department) VALUES (?, ?, ?)',
                 [ movie_id, name, department])
    end
  else
    puts "Failed to fetch cast and crew for movie ID #{movie_id}."
  end
end




# Create the database and tables
db = create_database

# Fetch popular movies with pagination
total_pages = 1 # Number of pages to fetch
(1..total_pages).each do |page|
  fetch_popular_movies(page, db)
end
