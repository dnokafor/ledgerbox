const sequelize = require('../config/database');
const User = require('./User');
const Account = require('./Account');
const Category = require('./Category');

// associations
User.hasMany(Account, { foreignKey: 'userId' });
Account.belongsTo(User, { foreignKey: 'userId' });

User.hasMany(Category, { foreignKey: 'userId' });
Category.belongsTo(User, { foreignKey: 'userId' });

const db = {
  sequelize,
  User,
  Account,
  Category,
};

module.exports = db;
