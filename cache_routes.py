from flask import Blueprint, render_template, request, flash, jsonify
from flask_login import login_required
import memcache
import boto3
import logging

logger = logging.getLogger(__name__)

cache_bp = Blueprint('cache', __name__)

def get_memcached_config():
    """Get Memcached configuration from AWS SSM Parameter Store"""
    try:
        ssm = boto3.client('ssm', region_name='us-east-1')
        endpoint = ssm.get_parameter(Name='/flask-app/cache/endpoint')['Parameter']['Value']
        port = ssm.get_parameter(Name='/flask-app/cache/port')['Parameter']['Value']
        return f"{endpoint}:{port}"
    except Exception as e:
        logger.error(f"Failed to get Memcached config: {str(e)}")
        return "localhost:11211"  # Default fallback

# Initialize Memcached client
mc = memcache.Client([get_memcached_config()])

@cache_bp.route('/cache', methods=['GET'])
@login_required
def cache_page():
    """Render the cache management page"""
    return render_template('cache.html')

@cache_bp.route('/api/cache', methods=['POST'])
@login_required
def set_cache():
    """Set a value in cache"""
    try:
        data = request.get_json()
        key = data.get('key')
        value = data.get('value')
        expiry = int(data.get('expiry', 3600))  # Default 1 hour expiry

        if not key or not value:
            return jsonify({'error': 'Key and value are required'}), 400

        success = mc.set(key, value, expiry)
        if success:
            logger.info(f"Successfully set cache key: {key}")
            return jsonify({'message': 'Value cached successfully'})
        else:
            logger.error(f"Failed to set cache key: {key}")
            return jsonify({'error': 'Failed to set cache value'}), 500

    except Exception as e:
        logger.error(f"Error setting cache: {str(e)}")
        return jsonify({'error': str(e)}), 500

@cache_bp.route('/api/cache/<key>', methods=['GET'])
@login_required
def get_cache(key):
    """Get a value from cache"""
    try:
        value = mc.get(key)
        if value is not None:
            return jsonify({'key': key, 'value': value})
        return jsonify({'error': 'Key not found'}), 404

    except Exception as e:
        logger.error(f"Error getting cache: {str(e)}")
        return jsonify({'error': str(e)}), 500

@cache_bp.route('/api/cache/<key>', methods=['DELETE'])
@login_required
def delete_cache(key):
    """Delete a value from cache"""
    try:
        success = mc.delete(key)
        if success:
            return jsonify({'message': 'Cache key deleted successfully'})
        return jsonify({'error': 'Key not found'}), 404

    except Exception as e:
        logger.error(f"Error deleting cache: {str(e)}")
        return jsonify({'error': str(e)}), 500 