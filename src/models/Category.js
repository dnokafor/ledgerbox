const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Category = sequelize.define('Category', {
  id: {
    type: DataTypes.INTEGER,
    autoIncrement: true,
    primaryKey: true,
  },
  name: {
    type: DataTypes.STRING(80),
    allowNull: false,
  },
  icon: {
    type: DataTypes.STRING(30),
    defaultValue: 'tag',
  },
  color: {
    type: DataTypes.STRING(7),
    defaultValue: '#6c757d',
  },
  userId: {
    type: DataTypes.INTEGER,
    allowNull: true, // null = global/default category
  },
}, {
  tableName: 'categories',
  timestamps: true,
});

module.exports = Category;
