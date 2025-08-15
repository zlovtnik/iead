#!/usr/bin/env node

/**
 * Frontend Bundle Analyzer
 * Analyzes the built frontend bundle for size, dependencies, and performance
 */

import { readFileSync, readdirSync, statSync } from 'fs';
import { join, extname } from 'path';
import { gzipSync } from 'zlib';

const BUNDLE_DIR = './dist';
const MAX_BUNDLE_SIZE = 500 * 1024; // 500KB
const MAX_CHUNK_SIZE = 200 * 1024; // 200KB
const MAX_GZIP_SIZE = 150 * 1024; // 150KB

class BundleAnalyzer {
  constructor() {
    this.results = {
      totalSize: 0,
      gzipSize: 0,
      files: [],
      chunks: [],
      warnings: [],
      recommendations: []
    };
  }

  analyzeFile(filePath) {
    try {
      const content = readFileSync(filePath);
      const stats = statSync(filePath);
      const gzipSize = gzipSync(content).length;
      
      return {
        path: filePath,
        size: stats.size,
        gzipSize: gzipSize,
        type: this.getFileType(filePath)
      };
    } catch (error) {
      console.warn(`⚠️  Could not analyze ${filePath}: ${error.message}`);
      return null;
    }
  }

  getFileType(filePath) {
    const ext = extname(filePath).toLowerCase();
    const fileName = filePath.toLowerCase();
    
    if (ext === '.js') {
      if (fileName.includes('vendor') || fileName.includes('chunk')) {
        return 'vendor';
      }
      return 'javascript';
    }
    if (ext === '.css') return 'stylesheet';
    if (['.png', '.jpg', '.jpeg', '.gif', '.svg', '.webp'].includes(ext)) return 'image';
    if (['.woff', '.woff2', '.ttf', '.eot'].includes(ext)) return 'font';
    return 'other';
  }

  analyzeBundleDirectory(dir = BUNDLE_DIR) {
    console.log(`🔍 Analyzing bundle directory: ${dir}`);
    
    try {
      const files = this.getAllFiles(dir);
      
      for (const file of files) {
        const analysis = this.analyzeFile(file);
        if (analysis) {
          this.results.files.push(analysis);
          this.results.totalSize += analysis.size;
          this.results.gzipSize += analysis.gzipSize;
        }
      }
      
      this.categorizeFiles();
      this.generateWarnings();
      this.generateRecommendations();
      
    } catch (error) {
      console.error(`❌ Error analyzing bundle: ${error.message}`);
      process.exit(1);
    }
  }

  getAllFiles(dir, files = []) {
    try {
      const dirFiles = readdirSync(dir);
      
      for (const file of dirFiles) {
        const fullPath = join(dir, file);
        const stat = statSync(fullPath);
        
        if (stat.isDirectory()) {
          this.getAllFiles(fullPath, files);
        } else {
          files.push(fullPath);
        }
      }
      
      return files;
    } catch (error) {
      throw new Error(`Cannot read directory ${dir}: ${error.message}`);
    }
  }

  categorizeFiles() {
    const categories = {};
    
    for (const file of this.results.files) {
      if (!categories[file.type]) {
        categories[file.type] = {
          count: 0,
          totalSize: 0,
          totalGzipSize: 0,
          files: []
        };
      }
      
      categories[file.type].count++;
      categories[file.type].totalSize += file.size;
      categories[file.type].totalGzipSize += file.gzipSize;
      categories[file.type].files.push(file);
    }
    
    this.results.categories = categories;
  }

  generateWarnings() {
    // Check total bundle size
    if (this.results.totalSize > MAX_BUNDLE_SIZE) {
      this.results.warnings.push({
        type: 'size',
        message: `Total bundle size (${this.formatSize(this.results.totalSize)}) exceeds recommended limit (${this.formatSize(MAX_BUNDLE_SIZE)})`
      });
    }

    // Check individual chunk sizes
    for (const file of this.results.files) {
      if (file.type === 'javascript' && file.size > MAX_CHUNK_SIZE) {
        this.results.warnings.push({
          type: 'chunk-size',
          message: `Large JavaScript chunk: ${file.path} (${this.formatSize(file.size)})`
        });
      }
    }

    // Check gzip size
    if (this.results.gzipSize > MAX_GZIP_SIZE) {
      this.results.warnings.push({
        type: 'gzip-size',
        message: `Total gzipped size (${this.formatSize(this.results.gzipSize)}) exceeds recommended limit (${this.formatSize(MAX_GZIP_SIZE)})`
      });
    }

    // Check for duplicate dependencies
    this.checkForDuplicates();
  }

  checkForDuplicates() {
    const jsFiles = this.results.files.filter(f => f.type === 'javascript');
    const suspiciousFiles = jsFiles.filter(f => 
      f.path.includes('vendor') || f.path.includes('chunk')
    );

    if (suspiciousFiles.length > 3) {
      this.results.warnings.push({
        type: 'chunking',
        message: `Multiple vendor/chunk files detected (${suspiciousFiles.length}). Consider optimizing code splitting.`
      });
    }
  }

  generateRecommendations() {
    const { categories } = this.results;

    // JavaScript optimization recommendations
    if (categories.javascript?.totalSize > 300 * 1024) {
      this.results.recommendations.push("Consider code splitting to reduce JavaScript bundle size");
    }

    // CSS optimization recommendations  
    if (categories.stylesheet?.totalSize > 100 * 1024) {
      this.results.recommendations.push("Consider CSS optimization and purging unused styles");
    }

    // Image optimization recommendations
    if (categories.image?.totalSize > 200 * 1024) {
      this.results.recommendations.push("Optimize images: use WebP format, compress images, implement lazy loading");
    }

    // Font optimization recommendations
    if (categories.font?.totalSize > 100 * 1024) {
      this.results.recommendations.push("Consider font optimization: use WOFF2, subset fonts, preload critical fonts");
    }

    // General recommendations based on compression ratio
    const compressionRatio = this.results.gzipSize / this.results.totalSize;
    if (compressionRatio > 0.7) {
      this.results.recommendations.push("Low compression ratio detected. Enable better compression or optimize assets");
    }
  }

  formatSize(bytes) {
    if (bytes === 0) return '0 B';
    const k = 1024;
    const sizes = ['B', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  }

  printReport() {
    console.log('\n📊 Bundle Analysis Report');
    console.log('='.repeat(50));
    
    // Overall statistics
    console.log('\n📈 Overall Statistics:');
    console.log(`Total Size: ${this.formatSize(this.results.totalSize)}`);
    console.log(`Gzipped Size: ${this.formatSize(this.results.gzipSize)}`);
    console.log(`Compression Ratio: ${((this.results.gzipSize / this.results.totalSize) * 100).toFixed(1)}%`);
    console.log(`Total Files: ${this.results.files.length}`);

    // Category breakdown
    console.log('\n📂 File Categories:');
    for (const [category, data] of Object.entries(this.results.categories)) {
      console.log(`${category.charAt(0).toUpperCase() + category.slice(1)}: ${data.count} files, ${this.formatSize(data.totalSize)} (${this.formatSize(data.totalGzipSize)} gzipped)`);
    }

    // Largest files
    console.log('\n📁 Largest Files:');
    const largestFiles = [...this.results.files]
      .sort((a, b) => b.size - a.size)
      .slice(0, 5);
    
    for (const file of largestFiles) {
      console.log(`${file.path}: ${this.formatSize(file.size)} (${this.formatSize(file.gzipSize)} gzipped)`);
    }

    // Warnings
    if (this.results.warnings.length > 0) {
      console.log('\n⚠️  Warnings:');
      for (const warning of this.results.warnings) {
        console.log(`• ${warning.message}`);
      }
    }

    // Recommendations
    if (this.results.recommendations.length > 0) {
      console.log('\n💡 Recommendations:');
      for (const recommendation of this.results.recommendations) {
        console.log(`• ${recommendation}`);
      }
    }

    // Performance score
    const score = this.calculatePerformanceScore();
    console.log(`\n🎯 Performance Score: ${score}/100`);
    
    if (score >= 90) {
      console.log('✅ Excellent bundle optimization!');
    } else if (score >= 70) {
      console.log('⚡ Good bundle optimization, minor improvements possible');
    } else if (score >= 50) {
      console.log('⚠️  Bundle optimization needs improvement');
    } else {
      console.log('❌ Bundle optimization requires significant improvement');
    }
  }

  calculatePerformanceScore() {
    let score = 100;

    // Deduct points for large bundle size
    if (this.results.totalSize > MAX_BUNDLE_SIZE) {
      score -= 20;
    }

    // Deduct points for poor compression
    const compressionRatio = this.results.gzipSize / this.results.totalSize;
    if (compressionRatio > 0.8) {
      score -= 15;
    }

    // Deduct points for warnings
    score -= this.results.warnings.length * 10;

    // Deduct points for too many files (indicating poor bundling)
    if (this.results.files.length > 20) {
      score -= 10;
    }

    return Math.max(0, score);
  }

  async saveReport() {
    const reportPath = `./bundle-analysis-${new Date().toISOString().split('T')[0]}.json`;
    try {
      const fs = await import('fs');
      fs.writeFileSync(reportPath, JSON.stringify(this.results, null, 2));
      console.log(`\n💾 Detailed report saved to: ${reportPath}`);
    } catch (error) {
      console.warn(`⚠️  Could not save report: ${error.message}`);
    }
  }
}

// Run analysis if this file is executed directly
if (process.argv[1] === new URL(import.meta.url).pathname) {
  const analyzer = new BundleAnalyzer();
  
  try {
    analyzer.analyzeBundleDirectory();
    analyzer.printReport();
    await analyzer.saveReport();
    
    // Exit with error code if there are critical issues
    const criticalWarnings = analyzer.results.warnings.filter(w => 
      w.type === 'size' || w.type === 'gzip-size'
    );
    
    if (criticalWarnings.length > 0) {
      console.log('\n❌ Critical bundle size issues detected!');
      process.exit(1);
    }
    
  } catch (error) {
    console.error(`❌ Bundle analysis failed: ${error.message}`);
    process.exit(1);
  }
}

export default BundleAnalyzer;
