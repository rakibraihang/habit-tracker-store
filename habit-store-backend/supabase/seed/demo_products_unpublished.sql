-- Optional seed based on the sample products currently hard-coded in the HTML.
-- Every row is unpublished by default. Review names, descriptions, actual prices,
-- inventory and delivery before publishing. This is NOT a production-approved catalog.
insert into public.products
  (slug, name, description, category, product_type, price, currency, stock_quantity, is_published)
values
  ('e1', 'The 30-Day Habit Reset', 'Sample catalog entry. Replace with the actual ebook and fulfillment details.', 'ebook', 'digital', 299, 'BDT', null, false),
  ('e2', 'Deep Focus Playbook', 'Sample catalog entry. Replace with the actual ebook and fulfillment details.', 'ebook', 'digital', 199, 'BDT', null, false),
  ('c1', 'Productivity Masterclass', 'Sample catalog entry. Replace with the actual course and fulfillment details.', 'course', 'digital', 1499, 'BDT', null, false),
  ('c2', 'Smart Money Habits', 'Sample catalog entry. Replace with the actual course and fulfillment details.', 'course', 'digital', 999, 'BDT', null, false),
  ('b1', 'Daily Productivity Journal (Printed)', 'Sample catalog entry. Confirm actual inventory before publishing.', 'book', 'physical', 450, 'BDT', 0, false),
  ('b2', 'Habit Building Handbook (Printed)', 'Sample catalog entry. Confirm actual inventory before publishing.', 'book', 'physical', 380, 'BDT', 0, false),
  ('g1', 'Smart Water Bottle 300ml (Stainless Steel)', 'Sample catalog entry. Confirm product specs and actual inventory.', 'gadget', 'physical', 650, 'BDT', 0, false),
  ('g2', 'Mushroom Lamp (USB Rechargeable Night Light)', 'Sample catalog entry. Confirm product specs and actual inventory.', 'gadget', 'physical', 1590, 'BDT', 0, false),
  ('g3', 'LED Camping Light (USB Rechargeable)', 'Sample catalog entry. Confirm product specs and actual inventory.', 'gadget', 'physical', 490, 'BDT', 0, false),
  ('g4', 'Desktop Fan with Light', 'Sample catalog entry. Confirm product specs and actual inventory.', 'gadget', 'physical', 1590, 'BDT', 0, false)
on conflict (slug) do nothing;
