require 'set'

class Picker
  # https://stackoverflow.com/questions/19261061/picking-a-random-option-where-each-option-has-a-different-probability-of-being/19261451
  def initialize(options, rng=Random.new)
    @rng = rng
    @options = options
  end

  def pick
    current, max = 0, @options.values.inject(:+)
    random_value = @rng.rand(max) + 1
    @options.each do |key,val|
       current += val
       return key if random_value <= current
    end
  end
end

def gauss_arr(num)
  if num % 2 == 0
    return (1..(num/2)).to_a + (1..(num/2)).to_a.reverse
  end
  return (1..(num/2)).to_a + [num/2+1] + (1..(num/2)).to_a.reverse
end

def gauss(min, max)
  options = Hash.new
  num = max - min + 1
  list = gauss_arr(num)

  list.each_with_index do |v, i|
    options[i + min] = v
  end
  return options
end

def random_dist(keys, vals = nil, rng)
  options = Hash.new
  if vals == nil
    vals = gauss(1, keys.length)
  end
  vals.shuffle(random: rng)
  for k in keys
    options[k] = vals.pop
  end
  return Picker.new(options, rng)
end

class Weapon
  #attr_reader :tohit
  def initialize(id, name, rng=Random.new, is_gauss=false)
    @id = id
    @name = name
    @rng = rng
    @tohit = @rng.rand(0.05..0.95).round(2)
    @damrange = @rng.rand(2..21)
    @mindamage = @rng.rand(1..5)
    @is_gauss = is_gauss
    @damagepicker = Picker.new(gauss(@mindamage, @mindamage + @damrange), rng)
  end

  def id
    return @id
  end

  def to_sql
    return "(#{@id}, '#{@name}', #{@tohit}, #{@mindamage}, #{@mindamage + @damrange})"
  end

  def hit
    return @tohit < @rng.rand ? 0 : 1
  end

  def damage
    maxdam = @mindamage + @damrange
    if @is_gauss
      return @damagepicker.pick
    else
      return @rng.rand(@mindamage..maxdam)
    end
  end
end

class TimeMaker
  def initialize(rng=Random.new)
    @rng = rng
    @cache = Set.new
  end

  def makedatetime
    # make sure we don't get duplicate times
    while true
      ts = "%d-%02d-%02d %02d:%02d:%02d" % [@rng.rand(2005..2013),
        @rng.rand(1..12), @rng.rand(1..28), @rng.rand(0...24),
        @rng.rand(0...60), @rng.rand(0...60)]
      if !@cache.include? ts
        @cache.add(ts)
        return ts
      end
    end
  end
end


def sql_weapons(weapons)
  return "DROP TABLE IF EXISTS weapon;
CREATE TABLE weapon (
  id integer PRIMARY KEY,
  name text,
  hitpct real,
  mindamage integer,
  maxdamage integer
);
INSERT INTO weapon (id, name, hitpct, mindamage, maxdamage)
VALUES\n" +
  weapons.collect{ |w| w.to_sql}.join(",\n") + ";"
end


def sql_ninjas(ninjas)
  sql = "DROP TABLE IF EXISTS ninja;
CREATE TABLE ninja (
  id integer PRIMARY KEY,
  name text
);
INSERT INTO ninja (id, name)
VALUES
"
  inserts = []
  for i in 0...(ninjas.length)
    inserts.append("(#{i+1}, '#{ninjas[i]}')")
  end
  return sql + inserts.join(",\n") + ";\n"
end


def make_weapons(weapon_names, rng=Random.new)
  weapons = Array.new
  # have 1 to 3 random weapons do a gaussian amount of damage
  gauss_weapons = (1..weapon_names.length).to_a.sample(rng.rand(1..3), random: rng)
  weapon_names.length.times do |i|
    if gauss_weapons.include? i
      weapons.append(Weapon.new(i+1, weapon_names[i], rng, true))
    else
      weapons.append(Weapon.new(i+1, weapon_names[i], rng))
    end
  end
  return weapons
end


def attacks(num_attacks=100, rng=Random.new(1234))
  # TODO: choose different random names
  # TODO: choose a different number of ninjas (i.e. between 8 and 12 total ninjas, or something)
  ninjas = ['alicia', 'bob', 'carlos', 'deandre', 'erika', 'feng', 'gina',
    'hai', 'ibrahim', 'jess']
  ids = (1..ninjas.length).to_a

  weapon_names = ['katana', 'bo stick', 'shuriken', 'nunchaku', 'blowgun',
    'wakizashi', 'quarterstaff', 'harsh words', 'sai']
  weapons = make_weapons(weapon_names, rng)

  # weapon prefs is a map from ninja ids to a "picker"
  # that will randomly select a weapon_id from a weighted sample
  #
  weapon_prefs = Hash.new
  # 50-50 change each ninja doesn't use one weapon
  # TODO: 
  for i in 1..(ids.length)
    weapon_prefs[i] = random_dist((0...weapons.length).to_a,
      [5, 10, 20, 30, 50, 5, 30, 90, [0,5].sample(random: rng)],
      rng)
  end

  # attacker_prefs is a hash from ninja ids to a "picker"
  # that randomly selects a target ninja id from a biased sampling
  #
  # each ninja has a 50-50 chance of not attacking one person
  #
  attacker_prefs = Hash.new
  for i in 1..(ids.length)
    attacker_prefs[i] = random_dist((1..ids.length).to_a,
      [5, 10, 20, 30, 50, 90, 10, 20, 40, [0,5].sample(random: rng)],
      rng)
  end

  attacks = Array.new

  timemaker = TimeMaker.new(rng)
  num_attacks.times do
    attacker = ids.sample(random: rng)

    # attackers should not actually attack themselves
    while (defender = attacker_prefs[attacker].pick) == attacker
    end

    #weapon = weapons.sample(random: rng)
    #STDERR.puts "attacker is #{attacker}"
    #STDERR.puts "weapon prefs is #{weapon_prefs[attacker]}"

    weapon_used = weapon_prefs[attacker].pick
    weapon = weapons[weapon_used]
    hit = weapon.hit
    damage = 0
    if hit == 1
      damage = weapon.damage
    end
    time = timemaker.makedatetime
    attacks.append("(#{attacker}, #{defender}, '#{time}', #{weapon.id}, #{hit}, #{damage})")
  end

  sql = sql_ninjas(ninjas)
  sql += sql_weapons(weapons)

  sql += "
DROP TABLE IF EXISTS attack;
CREATE TABLE attack (
  attacker_id integer,
  defender_id integer,
  time date,
  weapon_id integer,
  success integer,
  damage integer,
  PRIMARY KEY(attacker_id, defender_id, time)
);
"

  return sql + "INSERT INTO attack (attacker_id, defender_id, time, weapon_id, success, damage)\n" +
    "VALUES\n" + attacks.join(",\n")
end


if __FILE__ == $0
  puts attacks(200000)
end
