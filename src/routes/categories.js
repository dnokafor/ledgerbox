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
