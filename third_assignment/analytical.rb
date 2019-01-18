#!/usr/bin/env ruby

l_max = 2.6
l_step = 0.1
l = l_step

a = 0.2
b = 0.3
c = 0.5
d = 0.6
e = 0.4
f = 0.6
g = 0.2
h = 0.3

s1 = 0.003
s2 = 0.001
s3 = 0.01
s4 = 0.04
s5 = 0.1
s6 = 0.13
s7 = 0.15

v1 = 1
v2 = 1 / (1 - f)
v3 = v2 * a
v4 = v2 * b
v5 = v2 * c
v6 = ((1 / (1 - f)) + ((h * (e + (d * g))) / ((1 - f) * (1 - (h * g)))))
v7 = (e + (d * g)) / ((1 - f) * (1 - (h * g)))

r1 = v1 * s1
r2 = v2 * s2
r3 = v3 * s3
r4 = v4 * s4
r5 = v5 * s5
r6 = v6 * s6
r7 = v7 * s7

n1 = r1 * (1 - r1)
n2 = r2 * (1 - r2)
n3 = r3 * (1 - r3)
n4 = r4 * (1 - r4)
n5 = r5 * (1 - r5)
n6 = r6 * (1 - r6)
n7 = r7 * (1 - r7)

def print_var(sym ,b)
  print sym.to_s.upcase
  (1..7).each do |i|
    var = b.local_variable_get("#{sym}#{i}".to_sym)
    print " #{format("%1.6f", var)}"
  end
  print "\n"
end

print_var(:v, binding)
print_var(:r, binding)
print_var(:n, binding)

def t(l, b)
  t = 0
  (1..7).each do |i|
    r = b.local_variable_get("r#{i}".to_sym)
    t += r / (1 - l * r)
  end
  t
end

while l < l_max + l_step do
  puts "#{format("%1.6f", l)} #{format("%1.6f", t(l, binding))}"
  l += l_step
end
