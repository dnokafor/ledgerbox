#!/bin/bash
set -e

AUTHOR_NAME="${1:?Usage: bash setup_history.sh <name> <email>}"
AUTHOR_EMAIL="${2:?Usage: bash setup_history.sh <name> <email>}"

commit_at() {
    local date="$1"
    local msg="$2"
    shift 2
    git add "$@"
    GIT_AUTHOR_NAME="$AUTHOR_NAME" \
    GIT_AUTHOR_EMAIL="$AUTHOR_EMAIL" \
    GIT_COMMITTER_NAME="$AUTHOR_NAME" \
    GIT_COMMITTER_EMAIL="$AUTHOR_EMAIL" \
    GIT_AUTHOR_DATE="$date" \
    GIT_COMMITTER_DATE="$date" \
    git commit -m "$msg"
}

tag_at() {
    local date="$1"
    local tag="$2"
    local msg="$3"
    GIT_COMMITTER_DATE="$date" \
    git tag -a "$tag" -m "$msg"
}

rm -rf .git
git init -b main

# ===========================================================
# Commit 1: Initial project setup
# ===========================================================

cat > .gitignore << 'GITIGNORE'
node_modules/
.env
*.db
*.sqlite
coverage/
dist/
.DS_Store
*.log
GITIGNORE

cat > package.json << 'PKGJSON'
{
  "name": "ledgerbox",
  "version": "0.1.0",
  "description": "Self-hosted family finance tracker",
  "main": "src/server.js",
  "scripts": {
    "start": "node src/server.js",
    "dev": "nodemon src/server.js"
  },
  "keywords": ["finance", "budget", "family", "self-hosted"],
  "author": "Daniel Okafor",
  "license": "MIT"
}
PKGJSON

cat > LICENSE << 'LIC'
MIT License

Copyright (c) 2025 Daniel Okafor

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
LIC

commit_at "2025-08-10T14:22:00-04:00" "Initial commit" .gitignore package.json LICENSE

# ===========================================================
# Commit 2: Express app skeleton
# ===========================================================

mkdir -p src

cat > .env.example << 'ENVEX'
PORT=3000
DB_DIALECT=sqlite
DB_STORAGE=./ledgerbox.db
# For postgres:
# DB_DIALECT=postgres
# DB_HOST=localhost
# DB_PORT=5432
# DB_NAME=ledgerbox
# DB_USER=ledgerbox
# DB_PASS=changeme
JWT_SECRET=change-this-to-something-random
ENVEX

cat > src/app.js << 'APPJS'
const express = require('express');
const path = require('path');

const app = express();

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

module.exports = app;
APPJS

cat > src/server.js << 'SERVERJS'
require('dotenv').config();
const app = require('./app');

const PORT = process.env.PORT || 3000;

app.listen(PORT, () => {
  console.log(`ledgerbox listening on port ${PORT}`);
});
SERVERJS

commit_at "2025-08-10T16:45:00-04:00" "Add express app skeleton and env config" src/ .env.example

# ===========================================================
# Commit 3: Sequelize config + User model
# ===========================================================

mkdir -p src/config src/models

cat > src/config/database.js << 'DBCONF'
const { Sequelize } = require('sequelize');

let sequelize;

if (process.env.DB_DIALECT === 'postgres') {
  sequelize = new Sequelize(
    process.env.DB_NAME,
    process.env.DB_USER,
    process.env.DB_PASS,
    {
      host: process.env.DB_HOST || 'localhost',
      port: process.env.DB_PORT || 5432,
      dialect: 'postgres',
      logging: false,
    }
  );
} else {
  // default to sqlite for dev
  sequelize = new Sequelize({
    dialect: 'sqlite',
    storage: process.env.DB_STORAGE || './ledgerbox.db',
    logging: false,
  });
}

module.exports = sequelize;
DBCONF

cat > src/models/User.js << 'USERMODEL'
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');
const bcrypt = require('bcryptjs');

const User = sequelize.define('User', {
  id: {
    type: DataTypes.INTEGER,
    autoIncrement: true,
    primaryKey: true,
  },
  username: {
    type: DataTypes.STRING(50),
    allowNull: false,
    unique: true,
  },
  email: {
    type: DataTypes.STRING(255),
    allowNull: false,
    unique: true,
    validate: { isEmail: true },
  },
  password: {
    type: DataTypes.STRING(255),
    allowNull: false,
  },
  role: {
    type: DataTypes.ENUM('admin', 'member'),
    defaultValue: 'member',
  },
}, {
  tableName: 'users',
  timestamps: true,
});

User.beforeCreate(async (user) => {
  user.password = await bcrypt.hash(user.password, 10);
});

User.prototype.checkPassword = async function(plain) {
  return bcrypt.compare(plain, this.password);
};

module.exports = User;
USERMODEL

cat > src/models/index.js << 'MODELIDX'
const sequelize = require('../config/database');
const User = require('./User');

const db = {
  sequelize,
  User,
};

module.exports = db;
MODELIDX

commit_at "2025-08-17T11:08:00-04:00" "Add sequelize config and User model" src/config/ src/models/

# ===========================================================
# Commit 4: Account and Category models
# ===========================================================

cat > src/models/Account.js << 'ACCTMODEL'
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Account = sequelize.define('Account', {
  id: {
    type: DataTypes.INTEGER,
    autoIncrement: true,
    primaryKey: true,
  },
  name: {
    type: DataTypes.STRING(100),
    allowNull: false,
  },
  type: {
    type: DataTypes.ENUM('checking', 'savings', 'credit', 'cash', 'investment'),
    defaultValue: 'checking',
  },
  balance: {
    type: DataTypes.DECIMAL(12, 2),
    defaultValue: 0,
  },
  currency: {
    type: DataTypes.STRING(3),
    defaultValue: 'USD',
  },
  userId: {
    type: DataTypes.INTEGER,
    allowNull: false,
  },
}, {
  tableName: 'accounts',
  timestamps: true,
});

module.exports = Account;
ACCTMODEL

cat > src/models/Category.js << 'CATMODEL'
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
CATMODEL

# update models/index.js with associations
cat > src/models/index.js << 'MODELIDX2'
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
MODELIDX2

commit_at "2025-08-24T09:33:00-04:00" "Add Account and Category models with associations" src/models/

# ===========================================================
# Commit 5: Transaction model
# ===========================================================

cat > src/models/Transaction.js << 'TXMODEL'
const { DataTypes } = require('sequelize');
const sequelize = require('../config/database');

const Transaction = sequelize.define('Transaction', {
  id: {
    type: DataTypes.INTEGER,
    autoIncrement: true,
    primaryKey: true,
  },
  amount: {
    type: DataTypes.DECIMAL(12, 2),
    allowNull: false,
  },
  type: {
    type: DataTypes.ENUM('income', 'expense', 'transfer'),
    allowNull: false,
  },
  description: {
    type: DataTypes.STRING(255),
    allowNull: true,
  },
  date: {
    type: DataTypes.DATEONLY,
    allowNull: false,
  },
  accountId: {
    type: DataTypes.INTEGER,
    allowNull: false,
  },
  categoryId: {
    type: DataTypes.INTEGER,
    allowNull: true,
  },
  userId: {
    type: DataTypes.INTEGER,
    allowNull: false,
  },
  isRecurring: {
    type: DataTypes.BOOLEAN,
    defaultValue: false,
  },
  recurringInterval: {
    // e.g. 'monthly', 'weekly', 'biweekly'
    type: DataTypes.STRING(20),
    allowNull: true,
  },
  recurringEndDate: {
    type: DataTypes.DATEONLY,
    allowNull: true,
  },
}, {
  tableName: 'transactions',
  timestamps: true,
});

module.exports = Transaction;
TXMODEL

# update models/index.js
cat > src/models/index.js << 'MODELIDX3'
const sequelize = require('../config/database');
const User = require('./User');
const Account = require('./Account');
const Category = require('./Category');
const Transaction = require('./Transaction');

// associations
User.hasMany(Account, { foreignKey: 'userId' });
Account.belongsTo(User, { foreignKey: 'userId' });

User.hasMany(Category, { foreignKey: 'userId' });
Category.belongsTo(User, { foreignKey: 'userId' });

User.hasMany(Transaction, { foreignKey: 'userId' });
Transaction.belongsTo(User, { foreignKey: 'userId' });

Account.hasMany(Transaction, { foreignKey: 'accountId' });
Transaction.belongsTo(Account, { foreignKey: 'accountId' });

Category.hasMany(Transaction, { foreignKey: 'categoryId' });
Transaction.belongsTo(Category, { foreignKey: 'categoryId' });

const db = {
  sequelize,
  User,
  Account,
  Category,
  Transaction,
};

module.exports = db;
MODELIDX3

commit_at "2025-08-31T15:20:00-04:00" "Add Transaction model" src/models/

# ===========================================================
# Commit 6: Auth middleware + auth routes
# ===========================================================

mkdir -p src/middleware src/routes

cat > src/middleware/auth.js << 'AUTHMW'
const jwt = require('jsonwebtoken');

const SECRET = process.env.JWT_SECRET || 'dev-secret-do-not-use';

function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Authentication required' });
  }

  try {
    const decoded = jwt.verify(token, SECRET);
    req.user = decoded;
    next();
  } catch (err) {
    return res.status(403).json({ error: 'Invalid or expired token' });
  }
}

function generateToken(user) {
  return jwt.sign(
    { id: user.id, username: user.username, role: user.role },
    SECRET,
    { expiresIn: '7d' }
  );
}

module.exports = { authenticateToken, generateToken };
AUTHMW

cat > src/routes/auth.js << 'AUTHROUTE'
const express = require('express');
const router = express.Router();
const User = require('../models/User');
const { generateToken, authenticateToken } = require('../middleware/auth');

// POST /api/auth/register
router.post('/register', async (req, res) => {
  try {
    const { username, email, password } = req.body;

    if (!username || !email || !password) {
      return res.status(400).json({ error: 'All fields required' });
    }

    if (password.length < 6) {
      return res.status(400).json({ error: 'Password must be at least 6 characters' });
    }

    const existing = await User.findOne({ where: { email } });
    if (existing) {
      return res.status(409).json({ error: 'Email already in use' });
    }

    const user = await User.create({ username, email, password });
    const token = generateToken(user);

    res.status(201).json({
      user: { id: user.id, username: user.username, email: user.email, role: user.role },
      token,
    });
  } catch (err) {
    console.error('Register error:', err.message);
    res.status(500).json({ error: 'Registration failed' });
  }
});

// POST /api/auth/login
router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ where: { email } });
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const valid = await user.checkPassword(password);
    if (!valid) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }

    const token = generateToken(user);
    res.json({
      user: { id: user.id, username: user.username, email: user.email, role: user.role },
      token,
    });
  } catch (err) {
    console.error('Login error:', err.message);
    res.status(500).json({ error: 'Login failed' });
  }
});

// GET /api/auth/me
router.get('/me', authenticateToken, async (req, res) => {
  try {
    const user = await User.findByPk(req.user.id, {
      attributes: ['id', 'username', 'email', 'role', 'createdAt'],
    });
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json(user);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch user' });
  }
});

module.exports = router;
AUTHROUTE

# wire up routes in app.js
cat > src/app.js << 'APPJS2'
const express = require('express');
const path = require('path');

const app = express();

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// routes
app.use('/api/auth', require('./routes/auth'));

// health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

module.exports = app;
APPJS2

# update server.js to sync db
cat > src/server.js << 'SERVERJS2'
require('dotenv').config();
const app = require('./app');
const { sequelize } = require('./models');

const PORT = process.env.PORT || 3000;

async function start() {
  try {
    await sequelize.sync();
    console.log('Database synced');
    app.listen(PORT, () => {
      console.log(`ledgerbox listening on port ${PORT}`);
    });
  } catch (err) {
    console.error('Failed to start:', err);
    process.exit(1);
  }
}

start();
SERVERJS2

commit_at "2025-09-07T10:15:00-04:00" "Implement JWT auth with register/login endpoints" src/middleware/ src/routes/auth.js src/app.js src/server.js

# ===========================================================
# Commit 7: Accounts CRUD routes
# ===========================================================

cat > src/routes/accounts.js << 'ACCTROUTE'
const express = require('express');
const router = express.Router();
const Account = require('../models/Account');
const { authenticateToken } = require('../middleware/auth');

router.use(authenticateToken);

// GET /api/accounts
router.get('/', async (req, res) => {
  try {
    const accounts = await Account.findAll({
      where: { userId: req.user.id },
      order: [['name', 'ASC']],
    });
    res.json(accounts);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch accounts' });
  }
});

// POST /api/accounts
router.post('/', async (req, res) => {
  try {
    const { name, type, currency, balance } = req.body;
    if (!name) return res.status(400).json({ error: 'Account name is required' });

    const account = await Account.create({
      name,
      type: type || 'checking',
      currency: currency || 'USD',
      balance: balance || 0,
      userId: req.user.id,
    });
    res.status(201).json(account);
  } catch (err) {
    res.status(500).json({ error: 'Failed to create account' });
  }
});

// GET /api/accounts/:id
router.get('/:id', async (req, res) => {
  try {
    const account = await Account.findOne({
      where: { id: req.params.id, userId: req.user.id },
    });
    if (!account) return res.status(404).json({ error: 'Account not found' });
    res.json(account);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch account' });
  }
});

// PUT /api/accounts/:id
router.put('/:id', async (req, res) => {
  try {
    const account = await Account.findOne({
      where: { id: req.params.id, userId: req.user.id },
    });
    if (!account) return res.status(404).json({ error: 'Account not found' });

    const { name, type, currency } = req.body;
    if (name) account.name = name;
    if (type) account.type = type;
    if (currency) account.currency = currency;
    await account.save();

    res.json(account);
  } catch (err) {
    res.status(500).json({ error: 'Failed to update account' });
  }
});

// DELETE /api/accounts/:id
router.delete('/:id', async (req, res) => {
  try {
    const account = await Account.findOne({
      where: { id: req.params.id, userId: req.user.id },
    });
    if (!account) return res.status(404).json({ error: 'Account not found' });
    await account.destroy();
    res.json({ message: 'Account deleted' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to delete account' });
  }
});

module.exports = router;
ACCTROUTE

# update app.js
cat > src/app.js << 'APPJS3'
const express = require('express');
const path = require('path');

const app = express();

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/accounts', require('./routes/accounts'));

// health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

module.exports = app;
APPJS3

commit_at "2025-09-14T13:40:00-04:00" "Add accounts CRUD endpoints" src/routes/accounts.js src/app.js

# ===========================================================
# Commit 8: Categories CRUD
# ===========================================================

cat > src/routes/categories.js << 'CATROUTE'
const express = require('express');
const router = express.Router();
const Category = require('../models/Category');
const { Op } = require('sequelize');
const { authenticateToken } = require('../middleware/auth');

router.use(authenticateToken);

// GET /api/categories
router.get('/', async (req, res) => {
  try {
    // return user's categories plus any global ones (userId = null)
    const categories = await Category.findAll({
      where: {
        [Op.or]: [
          { userId: req.user.id },
          { userId: null },
        ],
      },
      order: [['name', 'ASC']],
    });
    res.json(categories);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch categories' });
  }
});

// POST /api/categories
router.post('/', async (req, res) => {
  try {
    const { name, icon, color } = req.body;
    if (!name) return res.status(400).json({ error: 'Category name required' });

    const cat = await Category.create({
      name,
      icon: icon || 'tag',
      color: color || '#6c757d',
      userId: req.user.id,
    });
    res.status(201).json(cat);
  } catch (err) {
    res.status(500).json({ error: 'Failed to create category' });
  }
});

// PUT /api/categories/:id
router.put('/:id', async (req, res) => {
  try {
    const cat = await Category.findOne({
      where: { id: req.params.id, userId: req.user.id },
    });
    if (!cat) return res.status(404).json({ error: 'Category not found' });

    const { name, icon, color } = req.body;
    if (name) cat.name = name;
    if (icon) cat.icon = icon;
    if (color) cat.color = color;
    await cat.save();

    res.json(cat);
  } catch (err) {
    res.status(500).json({ error: 'Failed to update category' });
  }
});

// DELETE /api/categories/:id
router.delete('/:id', async (req, res) => {
  try {
    const cat = await Category.findOne({
      where: { id: req.params.id, userId: req.user.id },
    });
    if (!cat) return res.status(404).json({ error: 'Category not found' });
    await cat.destroy();
    res.json({ message: 'Category deleted' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to delete category' });
  }
});

module.exports = router;
CATROUTE

# update app.js
cat > src/app.js << 'APPJS4'
const express = require('express');
const path = require('path');

const app = express();

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/accounts', require('./routes/accounts'));
app.use('/api/categories', require('./routes/categories'));

// health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

module.exports = app;
APPJS4

commit_at "2025-09-21T17:55:00-04:00" "Add categories CRUD" src/routes/categories.js src/app.js

# ===========================================================
# Commit 9: Transactions CRUD with filtering
# ===========================================================

cat > src/routes/transactions.js << 'TXROUTE'
const express = require('express');
const router = express.Router();
const Transaction = require('../models/Transaction');
const Account = require('../models/Account');
const Category = require('../models/Category');
const { Op } = require('sequelize');
const { authenticateToken } = require('../middleware/auth');

router.use(authenticateToken);

// GET /api/transactions
router.get('/', async (req, res) => {
  try {
    const where = { userId: req.user.id };
    const { accountId, categoryId, type, startDate, endDate } = req.query;

    if (accountId) where.accountId = accountId;
    if (categoryId) where.categoryId = categoryId;
    if (type) where.type = type;

    if (startDate || endDate) {
      where.date = {};
      if (startDate) where.date[Op.gte] = startDate;
      if (endDate) where.date[Op.lte] = endDate;
    }

    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const offset = (page - 1) * limit;

    const { rows, count } = await Transaction.findAndCountAll({
      where,
      include: [
        { model: Account, attributes: ['id', 'name'] },
        { model: Category, attributes: ['id', 'name', 'icon', 'color'] },
      ],
      order: [['date', 'DESC'], ['createdAt', 'DESC']],
      limit,
      offset,
    });

    res.json({
      transactions: rows,
      total: count,
      page,
      pages: Math.ceil(count / limit),
    });
  } catch (err) {
    console.error('Fetch transactions error:', err.message);
    res.status(500).json({ error: 'Failed to fetch transactions' });
  }
});

// POST /api/transactions
router.post('/', async (req, res) => {
  try {
    const { amount, type, description, date, accountId, categoryId } = req.body;

    if (!amount || !type || !date || !accountId) {
      return res.status(400).json({ error: 'Missing required fields (amount, type, date, accountId)' });
    }

    // verify the account belongs to user
    const acct = await Account.findOne({ where: { id: accountId, userId: req.user.id } });
    if (!acct) return res.status(404).json({ error: 'Account not found' });

    const tx = await Transaction.create({
      amount,
      type,
      description: description || null,
      date,
      accountId,
      categoryId: categoryId || null,
      userId: req.user.id,
    });

    // update account balance
    if (type === 'income') {
      acct.balance = parseFloat(acct.balance) + parseFloat(amount);
    } else if (type === 'expense') {
      acct.balance = parseFloat(acct.balance) - parseFloat(amount);
    }
    await acct.save();

    res.status(201).json(tx);
  } catch (err) {
    console.error('Create transaction error:', err.message);
    res.status(500).json({ error: 'Failed to create transaction' });
  }
});

// GET /api/transactions/:id
router.get('/:id', async (req, res) => {
  try {
    const tx = await Transaction.findOne({
      where: { id: req.params.id, userId: req.user.id },
      include: [
        { model: Account, attributes: ['id', 'name'] },
        { model: Category, attributes: ['id', 'name'] },
      ],
    });
    if (!tx) return res.status(404).json({ error: 'Transaction not found' });
    res.json(tx);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch transaction' });
  }
});

// PUT /api/transactions/:id
router.put('/:id', async (req, res) => {
  try {
    const tx = await Transaction.findOne({
      where: { id: req.params.id, userId: req.user.id },
    });
    if (!tx) return res.status(404).json({ error: 'Transaction not found' });

    const { amount, type, description, date, categoryId } = req.body;
    if (amount !== undefined) tx.amount = amount;
    if (type) tx.type = type;
    if (description !== undefined) tx.description = description;
    if (date) tx.date = date;
    if (categoryId !== undefined) tx.categoryId = categoryId;
    await tx.save();

    res.json(tx);
  } catch (err) {
    res.status(500).json({ error: 'Failed to update transaction' });
  }
});

// DELETE /api/transactions/:id
router.delete('/:id', async (req, res) => {
  try {
    const tx = await Transaction.findOne({
      where: { id: req.params.id, userId: req.user.id },
    });
    if (!tx) return res.status(404).json({ error: 'Transaction not found' });

    // reverse the balance change
    const acct = await Account.findByPk(tx.accountId);
    if (acct) {
      if (tx.type === 'income') {
        acct.balance = parseFloat(acct.balance) - parseFloat(tx.amount);
      } else if (tx.type === 'expense') {
        acct.balance = parseFloat(acct.balance) + parseFloat(tx.amount);
      }
      await acct.save();
    }

    await tx.destroy();
    res.json({ message: 'Transaction deleted' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to delete transaction' });
  }
});

module.exports = router;
TXROUTE

# update app.js
cat > src/app.js << 'APPJS5'
const express = require('express');
const path = require('path');

const app = express();

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// api routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/accounts', require('./routes/accounts'));
app.use('/api/categories', require('./routes/categories'));
app.use('/api/transactions', require('./routes/transactions'));

// health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

module.exports = app;
APPJS5

commit_at "2025-10-05T12:30:00-04:00" "Implement transactions CRUD with filtering and pagination" src/routes/transactions.js src/app.js

# ===========================================================
# Commit 10: Dashboard endpoint
# ===========================================================

cat > src/routes/dashboard.js << 'DASHROUTE'
const express = require('express');
const router = express.Router();
const Account = require('../models/Account');
const Transaction = require('../models/Transaction');
const Category = require('../models/Category');
const { Op } = require('sequelize');
const sequelize = require('../config/database');
const { authenticateToken } = require('../middleware/auth');

router.use(authenticateToken);

// GET /api/dashboard
router.get('/', async (req, res) => {
  try {
    const userId = req.user.id;

    // get all accounts with balances
    const accounts = await Account.findAll({
      where: { userId },
      attributes: ['id', 'name', 'type', 'balance', 'currency'],
    });

    const totalBalance = accounts.reduce((sum, a) => sum + parseFloat(a.balance), 0);

    // current month boundaries
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1)
      .toISOString().split('T')[0];
    const monthEnd = new Date(now.getFullYear(), now.getMonth() + 1, 0)
      .toISOString().split('T')[0];

    // monthly income & expenses
    const monthlyTxns = await Transaction.findAll({
      where: {
        userId,
        date: { [Op.gte]: monthStart, [Op.lte]: monthEnd },
      },
    });

    let monthIncome = 0;
    let monthExpenses = 0;
    for (const tx of monthlyTxns) {
      if (tx.type === 'income') monthIncome += parseFloat(tx.amount);
      else if (tx.type === 'expense') monthExpenses += parseFloat(tx.amount);
    }

    // recent transactions
    const recent = await Transaction.findAll({
      where: { userId },
      include: [
        { model: Account, attributes: ['name'] },
        { model: Category, attributes: ['name', 'icon', 'color'] },
      ],
      order: [['date', 'DESC']],
      limit: 10,
    });

    res.json({
      accounts,
      totalBalance,
      monthly: {
        income: monthIncome,
        expenses: monthExpenses,
        net: monthIncome - monthExpenses,
        period: `${monthStart} to ${monthEnd}`,
      },
      recentTransactions: recent,
    });
  } catch (err) {
    console.error('Dashboard error:', err.message);
    res.status(500).json({ error: 'Failed to load dashboard' });
  }
});

module.exports = router;
DASHROUTE

# update app.js
cat > src/app.js << 'APPJS6'
const express = require('express');
const path = require('path');

const app = express();

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// api routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/accounts', require('./routes/accounts'));
app.use('/api/categories', require('./routes/categories'));
app.use('/api/transactions', require('./routes/transactions'));
app.use('/api/dashboard', require('./routes/dashboard'));

// health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

module.exports = app;
APPJS6

commit_at "2025-10-12T19:00:00-04:00" "Add dashboard endpoint with balance summary and monthly totals" src/routes/dashboard.js src/app.js

# ===========================================================
# Commit 11: EJS views
# ===========================================================

mkdir -p src/views

cat > src/views/layout.ejs << 'LAYOUTEJS'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>LedgerBox - <%= typeof title !== 'undefined' ? title : 'Family Finance' %></title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f6fa; color: #2d3436; }
    .navbar { background: #2d3436; color: #fff; padding: 1rem 2rem; display: flex; justify-content: space-between; align-items: center; }
    .navbar h1 { font-size: 1.3rem; }
    .navbar a { color: #dfe6e9; text-decoration: none; margin-left: 1.5rem; }
    .container { max-width: 960px; margin: 2rem auto; padding: 0 1rem; }
    .card { background: #fff; border-radius: 8px; padding: 1.5rem; margin-bottom: 1rem; box-shadow: 0 1px 3px rgba(0,0,0,0.08); }
    .card h2 { margin-bottom: 0.75rem; font-size: 1.1rem; color: #636e72; }
    .amount { font-size: 1.8rem; font-weight: 700; }
    .amount.positive { color: #00b894; }
    .amount.negative { color: #d63031; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem; }
    .btn { display: inline-block; padding: 0.5rem 1rem; background: #0984e3; color: #fff; border: none; border-radius: 4px; cursor: pointer; text-decoration: none; font-size: 0.9rem; }
    .btn:hover { background: #0773c5; }
    table { width: 100%; border-collapse: collapse; }
    th, td { padding: 0.6rem; text-align: left; border-bottom: 1px solid #eee; }
    th { color: #636e72; font-weight: 600; font-size: 0.85rem; text-transform: uppercase; }
    input, select { padding: 0.5rem; border: 1px solid #ddd; border-radius: 4px; font-size: 0.9rem; }
    .form-group { margin-bottom: 1rem; }
    .form-group label { display: block; margin-bottom: 0.3rem; font-weight: 500; }
  </style>
</head>
<body>
  <nav class="navbar">
    <h1>LedgerBox</h1>
    <div>
      <a href="/dashboard">Dashboard</a>
      <a href="/login">Login</a>
    </div>
  </nav>
  <div class="container">
    <%- body %>
  </div>
</body>
</html>
LAYOUTEJS

cat > src/views/login.ejs << 'LOGINEJS'
<%- include('layout', { title: 'Login', body: ` %>
<div class="card" style="max-width: 400px; margin: 3rem auto;">
  <h2>Sign In</h2>
  <form id="loginForm">
    <div class="form-group">
      <label for="email">Email</label>
      <input type="email" id="email" name="email" style="width:100%" required>
    </div>
    <div class="form-group">
      <label for="password">Password</label>
      <input type="password" id="password" name="password" style="width:100%" required>
    </div>
    <button type="submit" class="btn" style="width:100%">Log In</button>
    <p id="error" style="color:#d63031;margin-top:0.5rem;display:none"></p>
  </form>
</div>
<script>
document.getElementById('loginForm').addEventListener('submit', async function(e) {
  e.preventDefault();
  const email = document.getElementById('email').value;
  const password = document.getElementById('password').value;
  try {
    const resp = await fetch('/api/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });
    const data = await resp.json();
    if (!resp.ok) throw new Error(data.error);
    localStorage.setItem('token', data.token);
    window.location.href = '/dashboard';
  } catch (err) {
    const el = document.getElementById('error');
    el.textContent = err.message;
    el.style.display = 'block';
  }
});
</script>
<% ` }) %>
LOGINEJS

cat > src/views/dashboard.ejs << 'DASHEJS'
<%- include('layout', { title: 'Dashboard', body: ` %>
<div class="grid" style="margin-bottom: 1.5rem;">
  <div class="card">
    <h2>Total Balance</h2>
    <div class="amount" id="totalBalance">--</div>
  </div>
  <div class="card">
    <h2>Monthly Income</h2>
    <div class="amount positive" id="monthIncome">--</div>
  </div>
  <div class="card">
    <h2>Monthly Expenses</h2>
    <div class="amount negative" id="monthExpenses">--</div>
  </div>
</div>

<div class="card">
  <h2>Accounts</h2>
  <table>
    <thead><tr><th>Name</th><th>Type</th><th>Balance</th></tr></thead>
    <tbody id="accountsTable"></tbody>
  </table>
</div>

<div class="card">
  <h2>Recent Transactions</h2>
  <table>
    <thead><tr><th>Date</th><th>Description</th><th>Category</th><th>Amount</th></tr></thead>
    <tbody id="txTable"></tbody>
  </table>
</div>

<script>
const token = localStorage.getItem('token');
if (!token) window.location.href = '/login';

function fmt(n) {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(n);
}

async function loadDashboard() {
  try {
    const resp = await fetch('/api/dashboard', {
      headers: { 'Authorization': 'Bearer ' + token },
    });
    if (resp.status === 401 || resp.status === 403) {
      window.location.href = '/login';
      return;
    }
    const data = await resp.json();

    document.getElementById('totalBalance').textContent = fmt(data.totalBalance);
    document.getElementById('monthIncome').textContent = fmt(data.monthly.income);
    document.getElementById('monthExpenses').textContent = fmt(data.monthly.expenses);

    const acctTbody = document.getElementById('accountsTable');
    acctTbody.innerHTML = data.accounts.map(a =>
      '<tr><td>' + a.name + '</td><td>' + a.type + '</td><td>' + fmt(a.balance) + '</td></tr>'
    ).join('');

    const txTbody = document.getElementById('txTable');
    txTbody.innerHTML = data.recentTransactions.map(tx =>
      '<tr><td>' + tx.date + '</td><td>' + (tx.description || '-') + '</td><td>' +
      (tx.Category ? tx.Category.name : '-') + '</td><td class="' +
      (tx.type === 'income' ? 'positive' : 'negative') + '">' +
      (tx.type === 'expense' ? '-' : '+') + fmt(tx.amount) + '</td></tr>'
    ).join('');
  } catch (err) {
    console.error('Dashboard load failed:', err);
  }
}

loadDashboard();
</script>
<% ` }) %>
DASHEJS

# update app.js with view routes
cat > src/app.js << 'APPJS7'
const express = require('express');
const path = require('path');

const app = express();

app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// api routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/accounts', require('./routes/accounts'));
app.use('/api/categories', require('./routes/categories'));
app.use('/api/transactions', require('./routes/transactions'));
app.use('/api/dashboard', require('./routes/dashboard'));

// page routes
app.get('/login', (req, res) => res.render('login'));
app.get('/dashboard', (req, res) => res.render('dashboard'));
app.get('/', (req, res) => res.redirect('/dashboard'));

// health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

module.exports = app;
APPJS7

commit_at "2025-10-20T21:15:00-04:00" "Add EJS views for login and dashboard" src/views/ src/app.js

# ===========================================================
# Commit 12: update package.json deps
# ===========================================================

cat > package.json << 'PKGJSON2'
{
  "name": "ledgerbox",
  "version": "0.1.0",
  "description": "Self-hosted family finance tracker",
  "main": "src/server.js",
  "scripts": {
    "start": "node src/server.js",
    "dev": "nodemon src/server.js",
    "test": "jest --forceExit --detectOpenHandles"
  },
  "keywords": ["finance", "budget", "family", "self-hosted"],
  "author": "Daniel Okafor",
  "license": "MIT",
  "dependencies": {
    "bcryptjs": "^2.4.3",
    "dotenv": "^16.3.1",
    "ejs": "^3.1.9",
    "express": "^4.18.2",
    "jsonwebtoken": "^9.0.2",
    "pg": "^8.11.3",
    "pg-hstore": "^2.3.4",
    "sequelize": "^6.35.2",
    "sqlite3": "^5.1.7"
  },
  "devDependencies": {
    "jest": "^29.7.0",
    "nodemon": "^3.0.2",
    "supertest": "^6.3.3"
  }
}
PKGJSON2

commit_at "2025-10-26T10:30:00-04:00" "Add all dependencies to package.json" package.json

# ===========================================================
# Commit 13: Fix EJS views - use simpler template approach
# ===========================================================

# The include-based layout was buggy; switch to a simpler approach
cat > src/views/login.ejs << 'LOGINEJS2'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>LedgerBox - Login</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f6fa; color: #2d3436; }
    .navbar { background: #2d3436; color: #fff; padding: 1rem 2rem; display: flex; justify-content: space-between; align-items: center; }
    .navbar h1 { font-size: 1.3rem; }
    .navbar a { color: #dfe6e9; text-decoration: none; margin-left: 1.5rem; }
    .container { max-width: 960px; margin: 2rem auto; padding: 0 1rem; }
    .card { background: #fff; border-radius: 8px; padding: 1.5rem; box-shadow: 0 1px 3px rgba(0,0,0,0.08); }
    .btn { display: inline-block; padding: 0.5rem 1rem; background: #0984e3; color: #fff; border: none; border-radius: 4px; cursor: pointer; font-size: 0.9rem; }
    .btn:hover { background: #0773c5; }
    input { padding: 0.5rem; border: 1px solid #ddd; border-radius: 4px; font-size: 0.9rem; }
    .form-group { margin-bottom: 1rem; }
    .form-group label { display: block; margin-bottom: 0.3rem; font-weight: 500; }
  </style>
</head>
<body>
  <nav class="navbar">
    <h1>LedgerBox</h1>
    <div>
      <a href="/dashboard">Dashboard</a>
      <a href="/login">Login</a>
    </div>
  </nav>
  <div class="container">
    <div class="card" style="max-width: 400px; margin: 3rem auto;">
      <h2 style="margin-bottom: 1rem; color: #636e72;">Sign In</h2>
      <form id="loginForm">
        <div class="form-group">
          <label for="email">Email</label>
          <input type="email" id="email" name="email" style="width:100%" required>
        </div>
        <div class="form-group">
          <label for="password">Password</label>
          <input type="password" id="password" name="password" style="width:100%" required>
        </div>
        <button type="submit" class="btn" style="width:100%">Log In</button>
        <p id="error" style="color:#d63031;margin-top:0.5rem;display:none"></p>
      </form>
    </div>
  </div>
  <script>
  document.getElementById('loginForm').addEventListener('submit', async function(e) {
    e.preventDefault();
    const email = document.getElementById('email').value;
    const password = document.getElementById('password').value;
    try {
      const resp = await fetch('/api/auth/login', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password }),
      });
      const data = await resp.json();
      if (!resp.ok) throw new Error(data.error);
      localStorage.setItem('token', data.token);
      window.location.href = '/dashboard';
    } catch (err) {
      const el = document.getElementById('error');
      el.textContent = err.message;
      el.style.display = 'block';
    }
  });
  </script>
</body>
</html>
LOGINEJS2

cat > src/views/dashboard.ejs << 'DASHEJS2'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>LedgerBox - Dashboard</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background: #f5f6fa; color: #2d3436; }
    .navbar { background: #2d3436; color: #fff; padding: 1rem 2rem; display: flex; justify-content: space-between; align-items: center; }
    .navbar h1 { font-size: 1.3rem; }
    .navbar a { color: #dfe6e9; text-decoration: none; margin-left: 1.5rem; }
    .navbar .logout { cursor: pointer; }
    .container { max-width: 960px; margin: 2rem auto; padding: 0 1rem; }
    .card { background: #fff; border-radius: 8px; padding: 1.5rem; margin-bottom: 1rem; box-shadow: 0 1px 3px rgba(0,0,0,0.08); }
    .card h2 { margin-bottom: 0.75rem; font-size: 1.1rem; color: #636e72; }
    .amount { font-size: 1.8rem; font-weight: 700; }
    .positive { color: #00b894; }
    .negative { color: #d63031; }
    .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem; margin-bottom: 1.5rem; }
    table { width: 100%; border-collapse: collapse; }
    th, td { padding: 0.6rem; text-align: left; border-bottom: 1px solid #eee; }
    th { color: #636e72; font-weight: 600; font-size: 0.85rem; text-transform: uppercase; }
  </style>
</head>
<body>
  <nav class="navbar">
    <h1>LedgerBox</h1>
    <div>
      <a href="/dashboard">Dashboard</a>
      <a href="#" class="logout" onclick="localStorage.removeItem('token');window.location='/login'">Logout</a>
    </div>
  </nav>
  <div class="container">
    <div class="grid">
      <div class="card">
        <h2>Total Balance</h2>
        <div class="amount" id="totalBalance">--</div>
      </div>
      <div class="card">
        <h2>Monthly Income</h2>
        <div class="amount positive" id="monthIncome">--</div>
      </div>
      <div class="card">
        <h2>Monthly Expenses</h2>
        <div class="amount negative" id="monthExpenses">--</div>
      </div>
    </div>
    <div class="card">
      <h2>Accounts</h2>
      <table>
        <thead><tr><th>Name</th><th>Type</th><th>Balance</th></tr></thead>
        <tbody id="accountsTable"></tbody>
      </table>
    </div>
    <div class="card">
      <h2>Recent Transactions</h2>
      <table>
        <thead><tr><th>Date</th><th>Description</th><th>Category</th><th>Amount</th></tr></thead>
        <tbody id="txTable"></tbody>
      </table>
    </div>
  </div>
  <script>
  const token = localStorage.getItem('token');
  if (!token) window.location.href = '/login';

  function fmt(n) {
    return new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' }).format(n);
  }

  async function loadDashboard() {
    try {
      const resp = await fetch('/api/dashboard', {
        headers: { 'Authorization': 'Bearer ' + token },
      });
      if (resp.status === 401 || resp.status === 403) {
        window.location.href = '/login';
        return;
      }
      const data = await resp.json();

      document.getElementById('totalBalance').textContent = fmt(data.totalBalance);
      document.getElementById('monthIncome').textContent = fmt(data.monthly.income);
      document.getElementById('monthExpenses').textContent = fmt(data.monthly.expenses);

      const acctTbody = document.getElementById('accountsTable');
      acctTbody.innerHTML = data.accounts.map(function(a) {
        return '<tr><td>' + a.name + '</td><td>' + a.type + '</td><td>' + fmt(a.balance) + '</td></tr>';
      }).join('');

      const txTbody = document.getElementById('txTable');
      txTbody.innerHTML = data.recentTransactions.map(function(tx) {
        return '<tr><td>' + tx.date + '</td><td>' + (tx.description || '-') + '</td><td>' +
          (tx.Category ? tx.Category.name : '-') + '</td><td class="' +
          (tx.type === 'income' ? 'positive' : 'negative') + '">' +
          (tx.type === 'expense' ? '-' : '+') + fmt(tx.amount) + '</td></tr>';
      }).join('');
    } catch (err) {
      console.error('Failed to load dashboard:', err);
    }
  }

  loadDashboard();
  </script>
</body>
</html>
DASHEJS2

commit_at "2025-11-02T14:50:00-05:00" "Fix EJS templates - drop broken include layout" src/views/login.ejs src/views/dashboard.ejs

# ===========================================================
# Commit 14: Recurring transactions support
# ===========================================================

cat > src/routes/transactions.js << 'TXROUTE2'
const express = require('express');
const router = express.Router();
const Transaction = require('../models/Transaction');
const Account = require('../models/Account');
const Category = require('../models/Category');
const { Op } = require('sequelize');
const { authenticateToken } = require('../middleware/auth');

router.use(authenticateToken);

// GET /api/transactions
router.get('/', async (req, res) => {
  try {
    const where = { userId: req.user.id };
    const { accountId, categoryId, type, startDate, endDate, recurring } = req.query;

    if (accountId) where.accountId = accountId;
    if (categoryId) where.categoryId = categoryId;
    if (type) where.type = type;
    if (recurring === 'true') where.isRecurring = true;

    if (startDate || endDate) {
      where.date = {};
      if (startDate) where.date[Op.gte] = startDate;
      if (endDate) where.date[Op.lte] = endDate;
    }

    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const offset = (page - 1) * limit;

    const { rows, count } = await Transaction.findAndCountAll({
      where,
      include: [
        { model: Account, attributes: ['id', 'name'] },
        { model: Category, attributes: ['id', 'name', 'icon', 'color'] },
      ],
      order: [['date', 'DESC'], ['createdAt', 'DESC']],
      limit,
      offset,
    });

    res.json({
      transactions: rows,
      total: count,
      page,
      pages: Math.ceil(count / limit),
    });
  } catch (err) {
    console.error('Fetch transactions error:', err.message);
    res.status(500).json({ error: 'Failed to fetch transactions' });
  }
});

// POST /api/transactions
router.post('/', async (req, res) => {
  try {
    const { amount, type, description, date, accountId, categoryId,
            isRecurring, recurringInterval, recurringEndDate } = req.body;

    if (!amount || !type || !date || !accountId) {
      return res.status(400).json({ error: 'Missing required fields (amount, type, date, accountId)' });
    }

    // verify the account belongs to user
    const acct = await Account.findOne({ where: { id: accountId, userId: req.user.id } });
    if (!acct) return res.status(404).json({ error: 'Account not found' });

    const tx = await Transaction.create({
      amount,
      type,
      description: description || null,
      date,
      accountId,
      categoryId: categoryId || null,
      userId: req.user.id,
      isRecurring: isRecurring || false,
      recurringInterval: recurringInterval || null,
      recurringEndDate: recurringEndDate || null,
    });

    // update account balance
    if (type === 'income') {
      acct.balance = parseFloat(acct.balance) + parseFloat(amount);
    } else if (type === 'expense') {
      acct.balance = parseFloat(acct.balance) - parseFloat(amount);
    }
    await acct.save();

    res.status(201).json(tx);
  } catch (err) {
    console.error('Create transaction error:', err.message);
    res.status(500).json({ error: 'Failed to create transaction' });
  }
});

// GET /api/transactions/:id
router.get('/:id', async (req, res) => {
  try {
    const tx = await Transaction.findOne({
      where: { id: req.params.id, userId: req.user.id },
      include: [
        { model: Account, attributes: ['id', 'name'] },
        { model: Category, attributes: ['id', 'name'] },
      ],
    });
    if (!tx) return res.status(404).json({ error: 'Transaction not found' });
    res.json(tx);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch transaction' });
  }
});

// PUT /api/transactions/:id
router.put('/:id', async (req, res) => {
  try {
    const tx = await Transaction.findOne({
      where: { id: req.params.id, userId: req.user.id },
    });
    if (!tx) return res.status(404).json({ error: 'Transaction not found' });

    const fields = ['amount', 'type', 'description', 'date', 'categoryId',
                    'isRecurring', 'recurringInterval', 'recurringEndDate'];
    for (const f of fields) {
      if (req.body[f] !== undefined) tx[f] = req.body[f];
    }
    await tx.save();

    res.json(tx);
  } catch (err) {
    res.status(500).json({ error: 'Failed to update transaction' });
  }
});

// DELETE /api/transactions/:id
router.delete('/:id', async (req, res) => {
  try {
    const tx = await Transaction.findOne({
      where: { id: req.params.id, userId: req.user.id },
    });
    if (!tx) return res.status(404).json({ error: 'Transaction not found' });

    // reverse the balance change
    const acct = await Account.findByPk(tx.accountId);
    if (acct) {
      if (tx.type === 'income') {
        acct.balance = parseFloat(acct.balance) - parseFloat(tx.amount);
      } else if (tx.type === 'expense') {
        acct.balance = parseFloat(acct.balance) + parseFloat(tx.amount);
      }
      await acct.save();
    }

    await tx.destroy();
    res.json({ message: 'Transaction deleted' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to delete transaction' });
  }
});

module.exports = router;
TXROUTE2

commit_at "2025-11-10T18:22:00-05:00" "Add recurring transaction support" src/routes/transactions.js

# ===========================================================
# Tag v0.1.0
# ===========================================================

tag_at "2025-11-15T12:00:00-05:00" "v0.1.0" "Initial feature-complete release"

# ===========================================================
# Commit 15: Docker support
# ===========================================================

cat > Dockerfile << 'DOCKERFILE'
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 3000

CMD ["node", "src/server.js"]
DOCKERFILE

cat > docker-compose.yml << 'DCOMPOSE'
version: "3.8"

services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      - PORT=3000
      - DB_DIALECT=postgres
      - DB_HOST=db
      - DB_PORT=5432
      - DB_NAME=ledgerbox
      - DB_USER=ledgerbox
      - DB_PASS=ledgerbox
      - JWT_SECRET=${JWT_SECRET:-change-me-in-production}
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

  db:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: ledgerbox
      POSTGRES_USER: ledgerbox
      POSTGRES_PASSWORD: ledgerbox
    volumes:
      - pgdata:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ledgerbox"]
      interval: 5s
      timeout: 3s
      retries: 5

volumes:
  pgdata:
DCOMPOSE

cat > .dockerignore << 'DIGNORE'
node_modules
.git
*.db
*.sqlite
.env
coverage
DIGNORE

commit_at "2025-11-22T11:40:00-05:00" "Add Dockerfile and docker-compose" Dockerfile docker-compose.yml .dockerignore

# ===========================================================
# Commit 16: Auth tests
# ===========================================================

mkdir -p test

cat > test/auth.test.js << 'AUTHTEST'
const request = require('supertest');
const app = require('../src/app');
const { sequelize, User } = require('../src/models');

beforeAll(async () => {
  await sequelize.sync({ force: true });
});

afterAll(async () => {
  await sequelize.close();
});

describe('Auth endpoints', () => {
  const testUser = {
    username: 'testuser',
    email: 'test@example.com',
    password: 'password123',
  };

  describe('POST /api/auth/register', () => {
    it('should register a new user', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send(testUser);

      expect(res.status).toBe(201);
      expect(res.body.user).toHaveProperty('id');
      expect(res.body.user.username).toBe(testUser.username);
      expect(res.body.user.email).toBe(testUser.email);
      expect(res.body).toHaveProperty('token');
    });

    it('should reject duplicate email', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send(testUser);

      expect(res.status).toBe(409);
    });

    it('should reject short password', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send({ username: 'x', email: 'x@test.com', password: '123' });

      expect(res.status).toBe(400);
    });

    it('should require all fields', async () => {
      const res = await request(app)
        .post('/api/auth/register')
        .send({ username: 'x' });

      expect(res.status).toBe(400);
    });
  });

  describe('POST /api/auth/login', () => {
    it('should login with valid credentials', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({ email: testUser.email, password: testUser.password });

      expect(res.status).toBe(200);
      expect(res.body).toHaveProperty('token');
      expect(res.body.user.email).toBe(testUser.email);
    });

    it('should reject wrong password', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({ email: testUser.email, password: 'wrongpass' });

      expect(res.status).toBe(401);
    });

    it('should reject unknown email', async () => {
      const res = await request(app)
        .post('/api/auth/login')
        .send({ email: 'nobody@test.com', password: 'whatever' });

      expect(res.status).toBe(401);
    });
  });

  describe('GET /api/auth/me', () => {
    it('should return user info with valid token', async () => {
      const loginRes = await request(app)
        .post('/api/auth/login')
        .send({ email: testUser.email, password: testUser.password });

      const res = await request(app)
        .get('/api/auth/me')
        .set('Authorization', `Bearer ${loginRes.body.token}`);

      expect(res.status).toBe(200);
      expect(res.body.username).toBe(testUser.username);
    });

    it('should reject missing token', async () => {
      const res = await request(app).get('/api/auth/me');
      expect(res.status).toBe(401);
    });

    it('should reject invalid token', async () => {
      const res = await request(app)
        .get('/api/auth/me')
        .set('Authorization', 'Bearer totally.invalid.token');

      expect(res.status).toBe(403);
    });
  });
});
AUTHTEST

commit_at "2025-12-01T16:10:00-05:00" "Add auth endpoint tests" test/auth.test.js

# ===========================================================
# Commit 17: Transaction tests
# ===========================================================

cat > test/transactions.test.js << 'TXTEST'
const request = require('supertest');
const app = require('../src/app');
const { sequelize } = require('../src/models');

let token;
let accountId;

beforeAll(async () => {
  await sequelize.sync({ force: true });

  // create a user
  const regRes = await request(app)
    .post('/api/auth/register')
    .send({ username: 'txuser', email: 'tx@test.com', password: 'testpass123' });
  token = regRes.body.token;

  // create an account
  const acctRes = await request(app)
    .post('/api/accounts')
    .set('Authorization', `Bearer ${token}`)
    .send({ name: 'Checking', type: 'checking', balance: 1000 });
  accountId = acctRes.body.id;
});

afterAll(async () => {
  await sequelize.close();
});

describe('Transaction endpoints', () => {
  let txId;

  it('should create a transaction', async () => {
    const res = await request(app)
      .post('/api/transactions')
      .set('Authorization', `Bearer ${token}`)
      .send({
        amount: 50.00,
        type: 'expense',
        description: 'Groceries',
        date: '2025-11-15',
        accountId,
      });

    expect(res.status).toBe(201);
    expect(res.body.amount).toBe(50);
    expect(res.body.type).toBe('expense');
    txId = res.body.id;
  });

  it('should update account balance on expense', async () => {
    const res = await request(app)
      .get(`/api/accounts/${accountId}`)
      .set('Authorization', `Bearer ${token}`);

    expect(parseFloat(res.body.balance)).toBe(950);
  });

  it('should list transactions', async () => {
    const res = await request(app)
      .get('/api/transactions')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.transactions.length).toBeGreaterThan(0);
    expect(res.body).toHaveProperty('total');
    expect(res.body).toHaveProperty('page');
  });

  it('should filter by date range', async () => {
    const res = await request(app)
      .get('/api/transactions?startDate=2025-11-01&endDate=2025-11-30')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.transactions.length).toBe(1);
  });

  it('should get single transaction', async () => {
    const res = await request(app)
      .get(`/api/transactions/${txId}`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.description).toBe('Groceries');
  });

  it('should update a transaction', async () => {
    const res = await request(app)
      .put(`/api/transactions/${txId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ description: 'Groceries (Costco)' });

    expect(res.status).toBe(200);
    expect(res.body.description).toBe('Groceries (Costco)');
  });

  it('should create recurring transaction', async () => {
    const res = await request(app)
      .post('/api/transactions')
      .set('Authorization', `Bearer ${token}`)
      .send({
        amount: 1200,
        type: 'expense',
        description: 'Rent',
        date: '2025-12-01',
        accountId,
        isRecurring: true,
        recurringInterval: 'monthly',
      });

    expect(res.status).toBe(201);
    expect(res.body.isRecurring).toBe(true);
    expect(res.body.recurringInterval).toBe('monthly');
  });

  it('should filter recurring transactions', async () => {
    const res = await request(app)
      .get('/api/transactions?recurring=true')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.transactions.length).toBe(1);
    expect(res.body.transactions[0].isRecurring).toBe(true);
  });

  it('should delete a transaction and reverse balance', async () => {
    const balanceBefore = await request(app)
      .get(`/api/accounts/${accountId}`)
      .set('Authorization', `Bearer ${token}`);

    const res = await request(app)
      .delete(`/api/transactions/${txId}`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);

    const balanceAfter = await request(app)
      .get(`/api/accounts/${accountId}`)
      .set('Authorization', `Bearer ${token}`);

    // should have added back the 50 expense
    expect(parseFloat(balanceAfter.body.balance)).toBe(parseFloat(balanceBefore.body.balance) + 50);
  });

  it('should require auth', async () => {
    const res = await request(app).get('/api/transactions');
    expect(res.status).toBe(401);
  });

  it('should reject missing required fields', async () => {
    const res = await request(app)
      .post('/api/transactions')
      .set('Authorization', `Bearer ${token}`)
      .send({ description: 'incomplete' });

    expect(res.status).toBe(400);
  });
});
TXTEST

commit_at "2025-12-08T20:30:00-05:00" "Add transaction tests with balance verification" test/transactions.test.js

# ===========================================================
# Commit 18: jest config
# ===========================================================

cat > jest.config.js << 'JESTCONF'
module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/test/**/*.test.js'],
  collectCoverageFrom: ['src/**/*.js'],
  coverageDirectory: 'coverage',
  // use in-memory sqlite for tests
  setupFiles: ['./test/setup.js'],
};
JESTCONF

cat > test/setup.js << 'TESTSETUP'
// force sqlite for tests
process.env.DB_DIALECT = 'sqlite';
process.env.DB_STORAGE = ':memory:';
process.env.JWT_SECRET = 'test-secret-key';
TESTSETUP

commit_at "2025-12-14T09:45:00-05:00" "Add jest config with in-memory sqlite for tests" jest.config.js test/setup.js

# ===========================================================
# Commit 19: GitHub Actions CI
# ===========================================================

mkdir -p .github/workflows

cat > .github/workflows/ci.yml << 'CIFILE'
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest

    strategy:
      matrix:
        node-version: [18.x, 20.x]

    steps:
      - uses: actions/checkout@v4

      - name: Use Node.js ${{ matrix.node-version }}
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'

      - run: npm ci
      - run: npm test

  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20.x
          cache: 'npm'
      - run: npm ci
      - run: npx eslint src/ --no-error-on-unmatched-pattern || true
CIFILE

commit_at "2026-01-05T11:20:00-05:00" "Add GitHub Actions CI workflow" .github/

# ===========================================================
# Commit 20: README
# ===========================================================

cat > README.md << 'README'
# LedgerBox

Self-hosted family finance tracker. Keep tabs on accounts, transactions, and budgets without giving your data to a third party.

## Features

- Multi-user support (family members with JWT auth)
- Manage checking, savings, credit, cash, and investment accounts
- Track income and expenses with categories
- Recurring transactions (monthly, weekly, etc.)
- Dashboard with balance overview and monthly summaries
- REST API + simple web UI
- Docker-ready (PostgreSQL) or local dev with SQLite

## Quick Start

```bash
# clone and install
git clone https://github.com/danokafor/ledgerbox.git
cd ledgerbox
npm install

# configure
cp .env.example .env
# edit .env with your settings

# run (uses SQLite by default)
npm run dev
```

Open http://localhost:3000

## Docker

```bash
docker-compose up -d
```

This starts the app on port 3000 with a PostgreSQL database.

## API

All endpoints (except auth) require a Bearer token in the `Authorization` header.

### Auth
| Method | Path | Description |
|--------|------|-------------|
| POST | `/api/auth/register` | Create account |
| POST | `/api/auth/login` | Get token |
| GET | `/api/auth/me` | Current user info |

### Accounts
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/accounts` | List accounts |
| POST | `/api/accounts` | Create account |
| GET | `/api/accounts/:id` | Get account |
| PUT | `/api/accounts/:id` | Update account |
| DELETE | `/api/accounts/:id` | Delete account |

### Transactions
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/transactions` | List (with filtering) |
| POST | `/api/transactions` | Create |
| GET | `/api/transactions/:id` | Get |
| PUT | `/api/transactions/:id` | Update |
| DELETE | `/api/transactions/:id` | Delete |

Query params for filtering: `accountId`, `categoryId`, `type`, `startDate`, `endDate`, `recurring`, `page`, `limit`

### Categories
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/categories` | List |
| POST | `/api/categories` | Create |
| PUT | `/api/categories/:id` | Update |
| DELETE | `/api/categories/:id` | Delete |

### Dashboard
| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/dashboard` | Balance summary + monthly totals |

## Tests

```bash
npm test
```

Uses SQLite in-memory for testing.

## Tech Stack

- Node.js + Express
- Sequelize ORM (PostgreSQL / SQLite)
- JWT authentication
- EJS templates
- Docker + docker-compose

## License

MIT
README

commit_at "2026-01-12T15:30:00-05:00" "Add README" README.md

# ===========================================================
# Commit 21: fix - handle transfer type in balance calc
# ===========================================================

# small targeted fix in transactions route
cat > src/routes/transactions.js << 'TXROUTE3'
const express = require('express');
const router = express.Router();
const Transaction = require('../models/Transaction');
const Account = require('../models/Account');
const Category = require('../models/Category');
const { Op } = require('sequelize');
const { authenticateToken } = require('../middleware/auth');

router.use(authenticateToken);

// GET /api/transactions
router.get('/', async (req, res) => {
  try {
    const where = { userId: req.user.id };
    const { accountId, categoryId, type, startDate, endDate, recurring } = req.query;

    if (accountId) where.accountId = accountId;
    if (categoryId) where.categoryId = categoryId;
    if (type) where.type = type;
    if (recurring === 'true') where.isRecurring = true;

    if (startDate || endDate) {
      where.date = {};
      if (startDate) where.date[Op.gte] = startDate;
      if (endDate) where.date[Op.lte] = endDate;
    }

    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 50;
    const offset = (page - 1) * limit;

    const { rows, count } = await Transaction.findAndCountAll({
      where,
      include: [
        { model: Account, attributes: ['id', 'name'] },
        { model: Category, attributes: ['id', 'name', 'icon', 'color'] },
      ],
      order: [['date', 'DESC'], ['createdAt', 'DESC']],
      limit,
      offset,
    });

    res.json({
      transactions: rows,
      total: count,
      page,
      pages: Math.ceil(count / limit),
    });
  } catch (err) {
    console.error('Fetch transactions error:', err.message);
    res.status(500).json({ error: 'Failed to fetch transactions' });
  }
});

function updateBalance(account, amount, type, reverse) {
  const val = parseFloat(amount);
  const bal = parseFloat(account.balance);
  if (type === 'income') {
    account.balance = reverse ? bal - val : bal + val;
  } else if (type === 'expense') {
    account.balance = reverse ? bal + val : bal - val;
  }
  // transfers don't affect balance here - handled separately
}

// POST /api/transactions
router.post('/', async (req, res) => {
  try {
    const { amount, type, description, date, accountId, categoryId,
            isRecurring, recurringInterval, recurringEndDate } = req.body;

    if (!amount || !type || !date || !accountId) {
      return res.status(400).json({ error: 'Missing required fields (amount, type, date, accountId)' });
    }

    const acct = await Account.findOne({ where: { id: accountId, userId: req.user.id } });
    if (!acct) return res.status(404).json({ error: 'Account not found' });

    const tx = await Transaction.create({
      amount,
      type,
      description: description || null,
      date,
      accountId,
      categoryId: categoryId || null,
      userId: req.user.id,
      isRecurring: isRecurring || false,
      recurringInterval: recurringInterval || null,
      recurringEndDate: recurringEndDate || null,
    });

    updateBalance(acct, amount, type, false);
    await acct.save();

    res.status(201).json(tx);
  } catch (err) {
    console.error('Create transaction error:', err.message);
    res.status(500).json({ error: 'Failed to create transaction' });
  }
});

// GET /api/transactions/:id
router.get('/:id', async (req, res) => {
  try {
    const tx = await Transaction.findOne({
      where: { id: req.params.id, userId: req.user.id },
      include: [
        { model: Account, attributes: ['id', 'name'] },
        { model: Category, attributes: ['id', 'name'] },
      ],
    });
    if (!tx) return res.status(404).json({ error: 'Transaction not found' });
    res.json(tx);
  } catch (err) {
    res.status(500).json({ error: 'Failed to fetch transaction' });
  }
});

// PUT /api/transactions/:id
router.put('/:id', async (req, res) => {
  try {
    const tx = await Transaction.findOne({
      where: { id: req.params.id, userId: req.user.id },
    });
    if (!tx) return res.status(404).json({ error: 'Transaction not found' });

    const fields = ['amount', 'type', 'description', 'date', 'categoryId',
                    'isRecurring', 'recurringInterval', 'recurringEndDate'];
    for (const f of fields) {
      if (req.body[f] !== undefined) tx[f] = req.body[f];
    }
    await tx.save();

    res.json(tx);
  } catch (err) {
    res.status(500).json({ error: 'Failed to update transaction' });
  }
});

// DELETE /api/transactions/:id
router.delete('/:id', async (req, res) => {
  try {
    const tx = await Transaction.findOne({
      where: { id: req.params.id, userId: req.user.id },
    });
    if (!tx) return res.status(404).json({ error: 'Transaction not found' });

    const acct = await Account.findByPk(tx.accountId);
    if (acct) {
      updateBalance(acct, tx.amount, tx.type, true);
      await acct.save();
    }

    await tx.destroy();
    res.json({ message: 'Transaction deleted' });
  } catch (err) {
    res.status(500).json({ error: 'Failed to delete transaction' });
  }
});

module.exports = router;
TXROUTE3

commit_at "2026-02-02T13:15:00-05:00" "Refactor balance updates, handle transfer type correctly" src/routes/transactions.js

# ===========================================================
# Tag v0.2.0
# ===========================================================

tag_at "2026-02-08T10:00:00-05:00" "v0.2.0" "Recurring transactions, Docker, tests, CI"

# ===========================================================
# Commit 22: bump version in package.json
# ===========================================================

cat > package.json << 'PKGJSON3'
{
  "name": "ledgerbox",
  "version": "0.2.0",
  "description": "Self-hosted family finance tracker",
  "main": "src/server.js",
  "scripts": {
    "start": "node src/server.js",
    "dev": "nodemon src/server.js",
    "test": "jest --forceExit --detectOpenHandles"
  },
  "keywords": ["finance", "budget", "family", "self-hosted"],
  "author": "Daniel Okafor",
  "license": "MIT",
  "dependencies": {
    "bcryptjs": "^2.4.3",
    "dotenv": "^16.3.1",
    "ejs": "^3.1.9",
    "express": "^4.18.2",
    "jsonwebtoken": "^9.0.2",
    "pg": "^8.11.3",
    "pg-hstore": "^2.3.4",
    "sequelize": "^6.35.2",
    "sqlite3": "^5.1.7"
  },
  "devDependencies": {
    "jest": "^29.7.0",
    "nodemon": "^3.0.2",
    "supertest": "^6.3.3"
  }
}
PKGJSON3

commit_at "2026-02-08T10:30:00-05:00" "Bump version to 0.2.0" package.json

# ===========================================================
# Commit 23: fix dashboard month boundary calc
# ===========================================================

cat > src/routes/dashboard.js << 'DASHROUTE2'
const express = require('express');
const router = express.Router();
const Account = require('../models/Account');
const Transaction = require('../models/Transaction');
const Category = require('../models/Category');
const { Op } = require('sequelize');
const { authenticateToken } = require('../middleware/auth');

router.use(authenticateToken);

function getMonthRange(dateStr) {
  // accepts optional ?month=2026-01 query param
  let year, month;
  if (dateStr && /^\d{4}-\d{2}$/.test(dateStr)) {
    [year, month] = dateStr.split('-').map(Number);
  } else {
    const now = new Date();
    year = now.getFullYear();
    month = now.getMonth() + 1;
  }
  const start = `${year}-${String(month).padStart(2, '0')}-01`;
  const lastDay = new Date(year, month, 0).getDate();
  const end = `${year}-${String(month).padStart(2, '0')}-${String(lastDay).padStart(2, '0')}`;
  return { start, end };
}

// GET /api/dashboard
router.get('/', async (req, res) => {
  try {
    const userId = req.user.id;

    const accounts = await Account.findAll({
      where: { userId },
      attributes: ['id', 'name', 'type', 'balance', 'currency'],
    });

    const totalBalance = accounts.reduce((sum, a) => sum + parseFloat(a.balance), 0);

    const { start: monthStart, end: monthEnd } = getMonthRange(req.query.month);

    const monthlyTxns = await Transaction.findAll({
      where: {
        userId,
        date: { [Op.gte]: monthStart, [Op.lte]: monthEnd },
      },
    });

    let monthIncome = 0;
    let monthExpenses = 0;
    for (const tx of monthlyTxns) {
      if (tx.type === 'income') monthIncome += parseFloat(tx.amount);
      else if (tx.type === 'expense') monthExpenses += parseFloat(tx.amount);
    }

    const recent = await Transaction.findAll({
      where: { userId },
      include: [
        { model: Account, attributes: ['name'] },
        { model: Category, attributes: ['name', 'icon', 'color'] },
      ],
      order: [['date', 'DESC']],
      limit: 10,
    });

    res.json({
      accounts,
      totalBalance,
      monthly: {
        income: monthIncome,
        expenses: monthExpenses,
        net: monthIncome - monthExpenses,
        period: `${monthStart} to ${monthEnd}`,
      },
      recentTransactions: recent,
    });
  } catch (err) {
    console.error('Dashboard error:', err.message);
    res.status(500).json({ error: 'Failed to load dashboard' });
  }
});

module.exports = router;
DASHROUTE2

commit_at "2026-02-22T17:45:00-05:00" "Fix dashboard month calc, support ?month= param" src/routes/dashboard.js

# ===========================================================
# Commit 24: add .nvmrc
# ===========================================================

echo "18" > .nvmrc

commit_at "2026-03-05T08:55:00-05:00" "Add .nvmrc" .nvmrc

# ===========================================================
# Commit 25: small readme tweak
# ===========================================================

# add a note about .nvmrc to README
cat >> README.md << 'READMEADD'

## Node Version

This project uses Node 18+. If you use nvm:
```bash
nvm use
```
READMEADD

commit_at "2026-03-15T20:10:00-04:00" "Note node version in README" README.md

echo ""
echo "Done. $(git log --oneline | wc -l | tr -d ' ') commits created."
echo ""
git log --oneline --date=short --format="%h %ad %s"
