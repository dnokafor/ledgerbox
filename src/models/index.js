const sequelize = require('../config/database');
const User = require('./User');

const db = {
  sequelize,
  User,
};

module.exports = db;
