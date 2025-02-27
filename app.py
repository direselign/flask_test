from flask import Flask, render_template, request, redirect, url_for, flash
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user, current_user
from models import db, User
from werkzeug.security import generate_password_hash, check_password_hash
from os import environ
from dotenv import load_dotenv
import logging
import boto3
from botocore.exceptions import ClientError

# Configure logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

def get_ssm_parameter(param_name, with_decryption=False):
    """
    Get a parameter from AWS Systems Manager Parameter Store
    """
    try:
        ssm = boto3.client('ssm', region_name='us-east-1')
        response = ssm.get_parameter(
            Name=param_name,
            WithDecryption=with_decryption
        )
        return response['Parameter']['Value']
    except ClientError as e:
        logger.error(f"Failed to get parameter {param_name}: {str(e)}")
        return None

# Get database credentials from SSM
db_user = get_ssm_parameter('/flask-app/db/username')
db_pass = get_ssm_parameter('/flask-app/db/password', with_decryption=True)
db_host = get_ssm_parameter('/flask-app/db/host')
db_port = get_ssm_parameter('/flask-app/db/port')
db_name = get_ssm_parameter('/flask-app/db/name')
flask_secret = get_ssm_parameter('/flask-app/secret-key', with_decryption=True)

# Load environment variables
load_dotenv()

app = Flask(__name__)
app.secret_key = flask_secret or environ.get('FLASK_SECRET_KEY')

# Database configuration
db_host = db_host or environ.get('DB_HOST', 'localhost')
db_port = db_port or environ.get('DB_PORT', '5432')
db_name = db_name or environ.get('DB_NAME', 'flaskapp')
db_user = db_user or environ.get('DB_USERNAME', 'postgres')
db_pass = db_pass or environ.get('DB_PASSWORD', '')

# Log database connection details (excluding password)
logger.info(f"Connecting to database at {db_host}:{db_port}/{db_name} as {db_user}")

app.config['SQLALCHEMY_DATABASE_URI'] = (
    f"postgresql://{db_user}:{db_pass}@{db_host}:{db_port}/{db_name}"
)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

# Initialize extensions
db.init_app(app)

# Initialize Flask-Login
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'landing'

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

@app.route('/')
def landing():
    if current_user.is_authenticated:
        return redirect(url_for('home'))
    return render_template('landing.html')

@app.route('/home')
@login_required
def home():
    return render_template('home.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
        user = User.query.filter_by(username=username).first()
        if user and check_password_hash(user.password, password):
            login_user(user)
            return redirect(url_for('home'))
        flash('Invalid username or password')
    
    return render_template('login.html')

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        email = request.form['email']

        if User.query.filter_by(username=username).first():
            flash('Username already exists')
            return redirect(url_for('register'))

        hashed_password = generate_password_hash(password)
        new_user = User(username=username, password=hashed_password, email=email)
        db.session.add(new_user)
        db.session.commit()

        flash('Registration successful! Please login.')
        return redirect(url_for('login'))

    return render_template('register.html')

@app.route('/logout')
@login_required
def logout():
    logout_user()
    return redirect(url_for('login'))

@app.route('/test-ssm')
def test_ssm():
    if not current_user.is_authenticated:
        return {"error": "Unauthorized"}, 401
        
    return {
        "db_host": db_host,
        "db_port": db_port,
        "db_name": db_name,
        "db_user": db_user,
        "connected": db.session.is_active
    }

# Create database tables
def init_db():
    with app.app_context():
        db.create_all()

if __name__ == '__main__':
    init_db()
    app.run(debug=True) 