import re
import yaml
import boto3
import statsd
import logging
from logging.handlers import RotatingFileHandler
from botocore.exceptions import NoCredentialsError
from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from flask_session import Session
from flask_httpauth import HTTPBasicAuth
from flask_bcrypt import Bcrypt
from datetime import *

app = Flask(__name__)
# Load the app configuration from app.yml
with open('app.yml', 'r') as f:
    config = yaml.safe_load(f)
    app.config.update(config)

# app.config['SQLALCHEMY_DATABASE_URI'] = 'postgresql://csye6225:123456@localhost:5432/cloudwebapp'
app.config['SQLALCHEMY_DATABASE_URI'] = f"postgresql://{app.config['RDS_USERNAME']}:{app.config['RDS_PASSWORD']}@{app.config['RDS_HOSTNAME']}/{app.config['RDS_DATABASENAME']}"
app.config["SECRET_KEY"] = '**********************'
app.config["SESSION_PERMANENT"] = False
app.config["SESSION_TYPE"]='filesystem'
db = SQLAlchemy(app)
bcrypt = Bcrypt(app)
Session(app)
auth = HTTPBasicAuth()

# Get AWS S3 bucket name
s3_bucket_name = config['S3_BUCKET_NAME']
# Create an S3 client object
s3 = boto3.client('s3')

statsd_client = statsd.StatsClient('localhost', 8125)

# configure root logger to log to console and file
root_logger = logging.getLogger()
root_logger.setLevel(logging.DEBUG)
formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
# log to file (max size 10MB, keep up to 5 backups)
file_handler = RotatingFileHandler('csye6225.log', maxBytes=10000000, backupCount=5)
file_handler.setLevel(logging.DEBUG)
file_handler.setFormatter(formatter)
root_logger.addHandler(file_handler)

statsd_client = statsd.StatsClient('localhost', 8125)

#user class
class User(db.Model):
    __tablename__ = 'user'
    id = db.Column(db.Integer, primary_key = True)
    first_name = db.Column(db.String(255), nullable=False)
    last_name = db.Column(db.String(255), nullable=False)
    email = db.Column(db.String(255), unique=True, nullable=False)
    password = db.Column(db.String(255), nullable=False)
    account_created = db.Column(db.DateTime, default=datetime.utcnow)
    account_updated = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def __repr__(self):
        return f'User("{self.id}","{self.first_name}","{self.last_name}","{self.email}")'

#product class
class Product(db.Model):
    __tablename__ = 'product'
    id = db.Column(db.Integer, primary_key = True)
    name = db.Column(db.String(255), nullable=True)
    description = db.Column(db.String(255), nullable=True)
    sku = db.Column(db.String(255), nullable=True)
    manufacturer = db.Column(db.String(255), nullable=True) 
    quantity = db.Column(db.Integer, nullable=False)
    date_added = db.Column(db.DateTime, default=datetime.utcnow)
    date_last_updated = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    owner_user_id = db.Column(db.Integer, db.ForeignKey('user.id'))
    
    def __repr__(self):
        return f'Product("{self.id}","{self.name}","{self.description}","{self.sku}","{self.manufacturer}","{self.quantity}","{self.owner_user_id}")'

class Image(db.Model):
    __tablename__ = 'image'
    id = db.Column(db.Integer, primary_key = True)
    product_id = db.Column(db.Integer, db.ForeignKey('product.id'), nullable=False)
    file_name = db.Column(db.String(255), nullable=False)
    date_created = db.Column(db.DateTime, default=datetime.utcnow)
    s3_bucket_path = db.Column(db.String(255), nullable=False)
    
    def __repr__(self):
        return f'Image("{self.id}","{self.product_id}","{self.file_name}","{self.date_created}","{self.s3_bucket_path}")'

# create table
with app.app_context():
    db.create_all()

@auth.verify_password
def verify_password(username, password):
    user = User.query.filter_by(email = username).first()

    if user and bcrypt.check_password_hash(user.password, password):
        return True
    return False

# ___________________________user namagement system________________________________

@app.route('/')
@statsd_client.timer('index.duration')
def index():
    statsd_client.incr('index.ApiCalls')
    app.logger.info('CSYE6225 PROJECT!')
    app.logger.debug("debug log info")
    app.logger.info("Info log information")
    app.logger.warning("Warning log info")
    app.logger.error("Error log info")
    app.logger.critical("Critical log info")
    return jsonify({'message': 'CSYE6225 PROJECT!'})

# User register
@app.route('/v1/user',methods=['POST'])
@statsd_client.timer('userSignup.duration')
def userSignup():
    statsd_client.incr('userSignup.ApiCalls')
    data = request.get_json()
    # get all input field name
    first_name = data.get('first_name')
    last_name = data.get('last_name')
    email = data.get('email')
    password = data.get('password')   
    # check all the field is filled are not
    if first_name =="" or last_name=="" or email=="" or password=="":
        return jsonify({'message': 'Please fill all the fields'}), 401
    #check if it's valid email
    if not re.match(r'^[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+){0,4}@[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+){0,4}$', email):
        return jsonify({'message': 'Please fill in correct email'}), 401
    else:
        #query database to see if there already has same email address
        is_email = User().query.filter_by(email=email).first()
        if is_email:
            return jsonify({'message': 'Email already exists!'}), 400
        else:
            hash_password = bcrypt.generate_password_hash(password, 10).decode('utf-8')
            new_user = User(email=email, password=hash_password, first_name=first_name, last_name=last_name)
            db.session.add(new_user)
            db.session.commit()
            return jsonify({'message': 'User created',
                            'username': email,
                            'first_name': first_name,
                            'last_name': last_name,
                            'account_created': new_user.account_created,
                            'account_updated': new_user.account_updated})

# Health endpoint
@app.route('/healthz',methods = ['GET'])
@statsd_client.timer('health.duration')
def health():
    statsd_client.incr('health.ApiCalls')
    return jsonify({'message': 'Server is healthy'}), 200
# Check new version
@app.route('/health',methods = ['GET'])
def health_newversion():
    return jsonify({'message': 'A new version!'}), 200

# get user account info(authenticated)
@app.route('/v1/user/<int:user_id>',methods = ['GET'])
@auth.login_required
@statsd_client.timer('getUserInfo.duration')
def getUserInfo(user_id):
    statsd_client.incr('getUserInfo.ApiCalls')
    find_user = User().query.filter_by(id=user_id).first()
    if find_user:
        return jsonify({'id': user_id,
                        'username': find_user.email,
                        'first_name': find_user.first_name,
                        'last_name': find_user.last_name,
                        'account_created': find_user.account_created,
                        'account_updated': find_user.account_updated})
    else:
        return jsonify({'message': 'User not found'}), 404

#user info update
@app.route('/v1/user/<int:user_id>',methods=["PUT"])
@statsd_client.timer('userInfoUpdate.duration')
def userInfoUpdate(user_id):
    statsd_client.incr('userInfoUpdate.ApiCalls')
    data = request.get_json()
    # get all input field name
    newf_name = data.get('first_name')
    newl_name = data.get('last_name')
    new_email = data.get('email')
    new_password = data.get('password')
    
    old_user = User().query.filter_by(id=user_id).first()
    if new_email == "" or new_password == "" or newf_name == "" or newl_name == "":
        return jsonify({'message': 'Lack of content'}), 401
    if old_user.email != new_email:
        return jsonify({'message': 'Can not modify email/username!'}), 400
    if not re.match(r'^[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+){0,4}@[a-zA-Z0-9_-]+(\.[a-zA-Z0-9_-]+){0,4}$', new_email):
        return jsonify({'message': 'Invalid email/username!'}), 400
    else:
        #update database
        hash_new_password = bcrypt.generate_password_hash(new_password, 10)
        User.query.filter_by(id=user_id).update(dict(first_name=newf_name,last_name=newl_name,password=hash_new_password))
        db.session.commit()
        return jsonify({'message': 'User information updated'})

# ___________________________Products Management System________________________________
# Add product
@app.route('/v1/product',methods=['POST'])
@auth.login_required
@statsd_client.timer('addProduct.duration')
def addProduct():
    statsd_client.incr('addProduct.ApiCalls')
    data = request.get_json()
    name = data.get('name')
    description = data.get('description')
    sku = data.get('sku')
    manufacturer = data.get('manufacturer')
    quantity = data.get('quantity')
    
    email = request.authorization.username
    addProd_user = User.query.filter_by(email = email).first()
    owner_user_id = addProd_user.id
    
    if quantity == "" or quantity < 0:
        return jsonify({'message': 'Please fill in correct quantity of product'}), 401
    has_sku = Product().query.filter_by(sku=sku).first()
    if has_sku:
        return jsonify({'message': 'SKU already exists!'}), 400
    else:
        new_product = Product(name=name, description=description, sku=sku, manufacturer=manufacturer, quantity=quantity, owner_user_id=owner_user_id)
        db.session.add(new_product)
        db.session.commit()
        return jsonify({'message': 'Product added',
                        'id': new_product.id,
                        'name': name,
                        'description': description,
                        'sku': sku,
                        'manufacturer': manufacturer,
                        'quantity': quantity,
                        'date_added': new_product.date_added,
                        'date_last_updated': new_product.date_last_updated,
                        'owner_user_id': new_product.owner_user_id})

#get product info(public)
@app.route('/v1/product/<int:product_id>',methods=['GET'])
@statsd_client.timer('getProductInfo.duration')
def getProductInfo(product_id):
    statsd_client.incr('getProductInfo.ApiCalls')
    find_prod = Product().query.filter_by(id=product_id).first()
    if not find_prod:
        return jsonify({'message': 'Did not find the product'}), 204
    else:
        return jsonify({'id': find_prod.id,
                        'name': find_prod.name,
                        'description': find_prod.description,
                        'sku': find_prod.sku,
                        'manufacturer': find_prod.manufacturer,
                        'quantity': find_prod.quantity,
                        'date_added': find_prod.date_added,
                        'date_last_updated': find_prod.date_last_updated,
                        'owner_user_id': find_prod.owner_user_id})

# Update product
@app.route('/v1/product/<int:product_id>',methods=['PUT','PATCH'])
@auth.login_required
@statsd_client.timer('updateProduct.duration')
def updateProduct(product_id):
    statsd_client.incr('updateProduct.ApiCalls')
    #check if the login user is the owner user
    prod_tobe_updated = Product().query.filter_by(id=product_id).first()
    email = auth.username()
    login_user = User().query.filter_by(email=email).first()
    if prod_tobe_updated.owner_user_id != login_user.id:
        return jsonify({'message': 'You are not the owner user!'}), 403
    else:
        if not prod_tobe_updated:
            return jsonify({'message': 'Did not find the product'}), 204
        prod_data = request.get_json()
        # get all input field name
        new_name = prod_data.get('name')
        new_description = prod_data.get('description')
        new_sku = prod_data.get('sku')
        new_manu = prod_data.get('manufacturer')
        new_quant = prod_data.get('quantity')

        if new_quant == "" or new_quant < 0:
            return jsonify({'message': 'Please input correct quantity'}), 204
        has_sku = Product().query.filter_by(sku=new_sku).first()
        if has_sku:
            return jsonify({'message': 'SKU already exists!'}), 400
        else:
            #update table product
            Product.query.filter_by(id=product_id).update(dict(name=new_name,description=new_description,sku=new_sku,manufacturer=new_manu,quantity=new_quant))
            updated_prod = Product().query.filter_by(id=product_id).first()
            db.session.commit()
            return jsonify({'message': 'Product added',
                            'id': updated_prod.id,
                            'name': new_name,
                            'description': new_description,
                            'sku': new_sku,
                            'manufacturer': new_manu,
                            'quantity': new_quant,
                            'date_added': updated_prod.date_added,
                            'date_last_updated': updated_prod.date_last_updated,
                            'owner_user_id': updated_prod.owner_user_id})

# Delete product
@app.route('/v1/product/<int:product_id>',methods=['DELETE'])
@auth.login_required
@statsd_client.timer('deleteProduct.duration')
def deleteProduct(product_id):
    statsd_client.incr('deleteProduct.ApiCalls')
    prod_tobe_deleted = Product().query.filter_by(id=product_id).first()
    email = auth.username()
    login_user = User().query.filter_by(email=email).first()
    if prod_tobe_deleted.owner_user_id != login_user.id:
        return jsonify({'message': 'You are not the owner user!'}), 403
    else:
        if not prod_tobe_deleted:
            return jsonify({'message': 'Did not find the product'}), 204
        else:
            #delete in database
            db.session.delete(prod_tobe_deleted)
            db.session.commit()
            return jsonify({'message': 'Delete item successfully'})
        
        
# ___________________________Products Images________________________________
# Get all images
@app.route('/v1/product/<int:product_id>/image',methods=['GET'])
@auth.login_required
@statsd_client.timer('getAllImages.duration')
def getAllImages(product_id):
    statsd_client.incr('getAllImages.ApiCalls')
    email = auth.username()
    login_user = User().query.filter_by(email=email).first()
    product_related = Product().query.filter_by(id=product_id).first()
    if product_related.owner_user_id != login_user.id:
        return jsonify({'message': 'You are not the owner user!'}), 403
    images = Image.query.filter_by(product_id=product_id).all()
    if not images:
        return jsonify({'message': 'No images found!'})
    else:
        image_list = []
        for image in images:
            image_data = {
                'image_id': image.id,
                'product_id': image.product_id,
                'file_name': image.file_name,
                'date_created': image.date_created.isoformat(),
                's3_bucket_path': image.s3_bucket_path
            }
            image_list.append(image_data)
        return jsonify(image_list)
    
# Upload an image
@app.route('/v1/product/<int:product_id>/image',methods=['POST'])
@auth.login_required
@statsd_client.timer('UploadanImage.duration')
def UploadanImage(product_id):
    statsd_client.incr('UploadanImage.ApiCalls')
    email = auth.username()
    login_user = User().query.filter_by(email=email).first()
    product_related = Product().query.filter_by(id=product_id).first()
    if product_related.owner_user_id != login_user.id:
        return jsonify({'message': 'You are not the owner user!'}), 403
    if 'file' not in request.files:
        return jsonify({'message': 'No file uploaded'}), 400
    file = request.files['file']
    file_name = file.filename
    # Upload the file to S3
    try:
        s3_key = f"{login_user.id}-{product_id}-{file_name}"
        s3.upload_fileobj(file, s3_bucket_name, s3_key)
        s3_bucket_path = f"https://{s3_bucket_name}.s3.amazonaws.com/{s3_key}"
        image = Image(product_id=product_id, file_name=file_name, s3_bucket_path=s3_bucket_path)
        db.session.add(image)
        db.session.commit()
        return jsonify({'message': 'Image uploaded successfully',
                            "id": image.id,
                            "product_id": image.product_id,
                            "file_name": image.file_name,
                            "date_created": image.date_created.isoformat(),
                            "s3_bucket_path": image.s3_bucket_path}), 201
    except NoCredentialsError:
        return jsonify({'message': 'Credentials not available'}), 401

# Get image detail
@app.route('/v1/product/<int:product_id>/image/<int:image_id>',methods=['GET'])
@auth.login_required
@statsd_client.timer('GetImageDetail.duration')
def GetImageDetail(product_id, image_id):
    statsd_client.incr('GetImageDetail.ApiCalls')
    imaged = Image.query.filter_by(id=image_id).first()
    if not imaged:
        return jsonify({'message': 'No images found!'})
    product_related = Product().query.filter_by(id=product_id).first()
    email = auth.username()
    login_user = User().query.filter_by(email=email).first()
    if not product_related or imaged.product_id != product_id:
        return jsonify({'message': 'The Product you entered did not match the product image'}), 204
    if product_related.owner_user_id != login_user.id:
        return jsonify({'message': 'You are not the owner user!'}), 403
    else:
        image_list = []
        image_data = {
            'image_id': imaged.id,
            'product_id': imaged.product_id,
            'file_name': imaged.file_name,
            'date_created': imaged.date_created.isoformat(),
            's3_bucket_path': imaged.s3_bucket_path
        }
        image_list.append(image_data)
        return jsonify(image_list)
# Delete image
@app.route('/v1/product/<int:product_id>/image/<int:image_id>',methods=['DELETE'])
@auth.login_required
@statsd_client.timer('DeleteImage.duration')
def DeleteImage(product_id, image_id):
    statsd_client.incr('DeleteImage.ApiCalls')
    img_tobe_deleted = Image().query.filter_by(id=image_id).first()
    if not img_tobe_deleted:
        return jsonify({'message': 'Did not find the image'}), 204
    product_related = Product().query.filter_by(id=product_id).first()
    email = auth.username()
    login_user = User().query.filter_by(email=email).first()
    if not product_related or img_tobe_deleted.product_id != product_id:
        return jsonify({'message': 'The Product you entered did not match the product image'}), 204
    if product_related.owner_user_id != login_user.id:
        return jsonify({'message': 'You are not the owner user!'}), 403
    else:
        #delete in s3 bucket
        s3_path = img_tobe_deleted.s3_bucket_path
        s3_key = s3_path.split('/')[-1]
        s3.delete_object(Bucket=s3_bucket_name, Key=s3_key)
        #delete in database
        db.session.delete(img_tobe_deleted)
        db.session.commit()
        return jsonify({'message': 'Delete image successfully'})

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=8081)