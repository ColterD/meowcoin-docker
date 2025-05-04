/**
 * E2E Tests for Onboarding Flow
 * Tests the complete onboarding process using Playwright
 */
const { test, expect } = require('@playwright/test');

test.describe('Onboarding Flow', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to the onboarding page
    await page.goto('/onboarding');
    
    // Wait for the page to load
    await page.waitForSelector('h1:has-text("Multi-Coin Blockchain Platform")');
  });
  
  test('should display the onboarding form', async ({ page }) => {
    // Check that the form is visible
    await expect(page.locator('#onboarding-form')).toBeVisible();
    
    // Check that the form has the expected fields
    await expect(page.locator('#coin')).toBeVisible();
    await expect(page.locator('#rpcUrl')).toBeVisible();
    await expect(page.locator('#network')).toBeVisible();
    await expect(page.locator('#enabled')).toBeVisible();
  });
  
  test('should show validation errors for empty fields', async ({ page }) => {
    // Submit the form without filling in required fields
    await page.locator('button[type="submit"]').click();
    
    // Check that validation errors are displayed
    await expect(page.locator('text=Please select a coin')).toBeVisible();
    await expect(page.locator('text=RPC URL is required')).toBeVisible();
  });
  
  test('should successfully submit a valid configuration', async ({ page }) => {
    // Fill in the form with valid data
    await page.selectOption('#coin', 'BTC');
    await page.fill('#rpcUrl', 'http://localhost:8332');
    await page.selectOption('#network', 'testnet');
    
    // Toggle advanced options
    await page.click('button:has-text("Advanced Options")');
    
    // Fill in advanced fields
    await page.fill('#minConfirmations', '2');
    await page.fill('#timeout', '60000');
    
    // Submit the form
    await page.locator('button[type="submit"]').click();
    
    // Check for success message
    await expect(page.locator('.alert-success')).toBeVisible();
    await expect(page.locator('.alert-success')).toContainText('Success');
  });
  
  test('should switch to feedback tab and submit feedback', async ({ page }) => {
    // Switch to feedback tab
    await page.click('button[role="tab"]:has-text("Feedback")');
    
    // Check that the feedback form is visible
    await expect(page.locator('#feedback-form')).toBeVisible();
    
    // Fill in the feedback form
    await page.fill('#feedback', 'This is a test feedback message');
    
    // Submit the form
    await page.locator('#feedback-form button[type="submit"]').click();
    
    // Check for success message
    await expect(page.locator('#feedback-result.alert-success')).toBeVisible();
    await expect(page.locator('#feedback-result')).toContainText('Thank you');
  });
  
  test('should toggle dark mode', async ({ page }) => {
    // Check initial theme
    const initialTheme = await page.evaluate(() => document.documentElement.getAttribute('data-theme'));
    
    // Toggle dark mode
    await page.click('#theme-toggle');
    
    // Check that the theme has changed
    const newTheme = await page.evaluate(() => document.documentElement.getAttribute('data-theme'));
    expect(newTheme).not.toEqual(initialTheme);
    
    // Toggle back
    await page.click('#theme-toggle');
    
    // Check that the theme has changed back
    const finalTheme = await page.evaluate(() => document.documentElement.getAttribute('data-theme'));
    expect(finalTheme).toEqual(initialTheme);
  });
});