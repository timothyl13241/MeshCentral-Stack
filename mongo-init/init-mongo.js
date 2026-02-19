// MongoDB Initialization Script for MeshCentral
// This script creates the MeshCentral database and user with appropriate permissions

// Get environment variables
const database = process.env.MONGO_INITDB_DATABASE;
const meshcentralUser = process.env.MESHCENTRAL_USER;
const meshcentralPassword = process.env.MESHCENTRAL_PASSWORD;

print('=================================================');
print('Starting MongoDB initialization for MeshCentral');
print('=================================================');

// Switch to the MeshCentral database
db = db.getSiblingDB(database);

print('Creating MeshCentral database: ' + database);

// Create the MeshCentral user with read/write permissions
print('Creating MeshCentral user: ' + meshcentralUser);

try {
    db.createUser({
        user: meshcentralUser,
        pwd: meshcentralPassword,
        roles: [
            {
                role: 'readWrite',
                db: database
            },
            {
                role: 'dbAdmin',
                db: database
            }
        ]
    });
    print('✓ Successfully created MeshCentral user');
} catch (error) {
    print('⚠ User creation failed (may already exist): ' + error);
}

// Create initial collections with validation (optional but recommended)
try {
    db.createCollection('meshcentral', {
        validator: {
            $jsonSchema: {
                bsonType: 'object',
                description: 'MeshCentral main collection'
            }
        }
    });
    print('✓ Created meshcentral collection');
} catch (error) {
    print('⚠ Collection creation skipped (may already exist): ' + error);
}

// Create indexes for better performance
try {
    db.meshcentral.createIndex({ "type": 1 });
    db.meshcentral.createIndex({ "domain": 1 });
    db.meshcentral.createIndex({ "email": 1 });
    db.meshcentral.createIndex({ "meshid": 1 });
    print('✓ Created performance indexes');
} catch (error) {
    print('⚠ Index creation warning: ' + error);
}

print('=================================================');
print('MongoDB initialization completed successfully');
print('Database: ' + database);
print('User: ' + meshcentralUser);
print('=================================================');
