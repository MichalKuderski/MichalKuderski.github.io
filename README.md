# Michal Kuderski - Data Portfolio

Welcome to my personal portfolio website showcasing my data analysis and statistical modeling projects.

## 📁 How to Save Folders in Git/GitHub

### The Problem
Git doesn't track empty directories. When you create a folder on your Mac's Finder and try to commit it to GitHub, the folder won't appear in GitHub Desktop if it's empty.

### The Solution
To make Git track a folder, you need at least one file inside it. There are two common approaches:

#### Option 1: Add a `.gitkeep` file (Recommended)
This is a convention used to track empty directories. The `.gitkeep` file is just a placeholder that tells Git to include the folder.

```bash
# Create a folder
mkdir my-folder

# Add a .gitkeep file to make Git track it
touch my-folder/.gitkeep

# Now Git will track this folder!
git add my-folder/.gitkeep
git commit -m "Add my-folder directory"
```

#### Option 2: Add an empty `.gitignore` file
Another common approach is to add an empty `.gitignore` file in the directory.

```bash
mkdir my-folder
touch my-folder/.gitignore
git add my-folder/.gitignore
git commit -m "Add my-folder directory"
```

### Using GitHub Desktop on Mac
1. **Create folders** in Finder as usual
2. **Add a `.gitkeep` file** to each empty folder you want to track
3. **Open GitHub Desktop** - you should now see the folders listed
4. **Commit and push** your changes

## 📂 Project Structure

This repository is organized as follows:

```
.
├── index.html          # Main portfolio page
├── css/                # CSS stylesheets (currently using CDN)
├── js/                 # JavaScript files
├── images/             # Image assets
└── assets/             # Other assets
    ├── icons/          # Icon files
    └── documents/      # PDF, resume, etc.
```

Each empty folder contains a `.gitkeep` file so Git tracks the folder structure. Once you add actual files (CSS, JS, images), you can delete the `.gitkeep` files if you want.

## 🚀 Live Site

Visit the portfolio at: [https://michalkuderski.github.io](https://michalkuderski.github.io)

## 💼 Featured Projects

- **Quantium Retail Strategy** - Retail analytics using R
- **Corn Yield ANOVA** - Agricultural statistical simulation
- **ML Classification** - Animal classification with Random Forest
- **Student Performance Modeling** - Predictive analytics for academic success

## 📫 Contact

- Email: mkuderski21@gmail.com
- LinkedIn: [Michal Kuderski](https://www.linkedin.com/in/michal-kuderski-4b10a8230/)
- GitHub: [MichalKuderski](https://github.com/MichalKuderski)

---

**Note for Mac Users**: Remember, Git tracks *files*, not folders. Always add at least one file (like `.gitkeep`) to any folder you want to include in your repository.
