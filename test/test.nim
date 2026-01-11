import ../src/tabulator
import std/[terminal]

var t = newTable()

# Add many columns
t.addColumn("ID", width = 4, align = Right)
t.addColumn("\e[1mProduct Name\e[0m", width = 20)
t.addColumn("Category", width = 12)
t.addColumn("Supplier")
t.addColumn("Price USD", align = Right)
t.addColumn("Qty", align = Center)
t.addColumn("Weight (kg)", align = Right)
t.addColumn("Last Updated")
t.addColumn("Status")
t.addColumn("Rating", align = Center)

# Add rows with varied content
t.addRow(@["001", "Organic Apples", "Fruit", "Fresh Farms Inc.", "2.50", "150", "1.2", "2024-03-15", "\e[32mIn Stock\e[0m", "★★★★☆"])
t.addRow(@["002", "Bananas Fair Trade", "Fruit", "Tropical Imports", "1.20", "75", "0.8", "2024-03-14", "\e[32mIn Stock\e[0m", "★★★☆☆"])
t.addRow(@["003", "Artisanal Bread", "Bakery", "Local Bakery Co.", "5.99", "23", "0.5", "2024-03-15", "\e[33mLimited\e[0m", "★★★★★"])
t.addRow(@["004", "Extra Virgin Olive Oil", "Condiments", "Mediterranean Goods", "12.99", "42", "0.75", "2024-03-13", "\e[32mIn Stock\e[0m", "★★★★☆"])
t.addRow(@["005", "Greek Yogurt", "Dairy", "Dairy Fresh Ltd.", "3.49", "89", "0.45", "2024-03-15", "\e[32mIn Stock\e[0m", "★★★☆☆"])
t.addRow(@["006", "Free-Range Eggs (12)", "Dairy", "Happy Hens Farm", "4.99", "34", "0.7", "2024-03-14", "\e[31mOut of Stock\e[0m", "★★★★☆"])
t.addRow(@["007", "Dark Chocolate 85%", "Snacks", "Choco Deluxe", "8.50", "56", "0.1", "2024-03-12", "\e[32mIn Stock\e[0m", "★★★★★"])
t.addRow(@["008", "Quinoa Organic", "Grains", "Health Foods Intl.", "6.75", "28", "0.9", "2024-03-11", "\e[33mLimited\e[0m", "★★★☆☆"])
t.addRow(@["009", "Maple Syrup Grade A", "Condiments", "Canadian Harvest", "15.25", "19", "0.5", "2024-03-10", "\e[32mIn Stock\e[0m", "★★★★☆"])
t.addRow(@["010", "Almond Milk Unsweetened", "Beverages", "Nutty Goodness", "3.99", "67", "0.95", "2024-03-15", "\e[32mIn Stock\e[0m", "★★★☆☆"])

echo "=== Testing with separator=true ==="
echo "Terminal width: ", terminalWidth()
t.renderTable(separator = true)
var f: File
if open(f, "tabulator_test.txt", fmWrite):
  t.renderTable(separator = true, outFile = f)
  t.renderTable(separator = false, outFile = f)
  close(f)

echo "\n=== Testing with separator=false ==="
t.renderTable(separator = false)

echo "\n=== Testing with very long cell content ==="
var t2 = newTable()
t2.addColumn("Short", width = 5)
t2.addColumn("Auto Width Test")
t2.addColumn("Fixed Truncate", width = 8)
t2.addColumn("Right Aligned", align = Right)

t2.addRow(@["A", "This is a moderately long piece of text that will force auto-width", "This should be truncated with ellipsis because it's too long", "42"])
t2.addRow(@["B", "Short", "1234567890", "\e[31m-15\e[0m"])
t2.addRow(@["", "Another test with \e[1mANSI\e[0m codes that don't affect width", "Hi", "9999"])

t2.renderTable(separator = true)
t2.renderTable(separator = true, width=40)
t2.renderTable(separator = true, width=80)
t2.renderTable(separator = true, width=120)
t2.renderTable(separator = true, width=160)
t2.renderTable(separator = true, width=200)

echo "\n=== Testing edge cases ==="
var t3 = newTable()
t3.addRow(@["Tab", "separated", "output"])
t3.addRow(@["Works", "without", "columns"])
echo "No columns test:"
t3.renderTable()

echo "\n=== Testing empty table with header ==="
var t4 = newTable()
t4.addColumn("Empty", width = 10)
t4.addColumn("Table")
t4.renderTable(separator = true)

echo "\n=== Testing single column ==="
var t5 = newTable()
t5.addColumn("Single Column Table")
t5.addRow(@["First row"])
t5.addRow(@["Second row with \e[34mcolor\e[0m"])
t5.renderTable(separator = true)

echo "\n=== Testing with no header ==="
var t6 = newTable()
t6.addRow(@["A", "This is a moderately long piece of text that will force auto-width", "This should be truncated with ellipsis because it's too long", "42"])
t6.addRow(@["B", "Short", "1234567890", "\e[31m-15\e[0m"])
t6.addRow(@["", "Another test with \e[1mANSI\e[0m codes that don't affect width", "Hi", "9999"])

t6.renderTable(separator = true, width=160)
t6.renderTable(separator = false, width=160)