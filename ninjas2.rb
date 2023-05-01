require 'set'

if ARGV.empty?
    puts "Usage: ninjas2.rb [ <num_rows> <name_file> <seed> ]"
    exit 1
end

# how many rows of attacks?
num_rows = 1000
if ARGV.size > 0
    num_rows = ARGV.shift.to_i
end
name_file = nil
if ARGV.size > 0
    name_file = ARGV.shift
end

# create global rng with seed value given in command line
seed = 5
if ARGV.size > 0
    seed = ARGV.shift.to_i
end
STDERR.puts "seed is #{seed}"
$rng = Random.new(seed)


$profiles = [:minmax] * 4 + [:_1d6, :_2d6, :_3d6, :_1d8, :_2d8, :_3d8, :_1d10, :_2d10]

def flip(num=2)
    # heads or tails coin flip
    return $rng.rand(1..num) == 1
end

def gauss_arr(num)
    return (1..(num/2)).to_a + (1..(num/2)).to_a.reverse if num % 2 == 0
    return (1..(num/2)).to_a + [num/2+1] + (1..(num/2)).to_a.reverse
end

def gauss_profile(arr)
    newarr = Array.new
    arr.shuffle(random: $rng)
    gauss_arr(arr.size).each_with_index do |num, i|
        num.times do
            newarr << arr[i]
        end
    end
    return newarr
end

def frenemy(arr)
    x = arr.sample(random: $rng)
    arr.delete(x)
    arr = gauss_profile(arr)
    return [x] * arr.size + arr
end

class TimeMaker
    def initialize
        @start = Time.local(2010, 1, 1)
        @end = Time.local(2020, 12, 31)
        @cache = Set.new
        
        @skip_years = Set.new
        @skip_months = Set.new
        if flip
            # remove 1..3 years
            $rng.rand(1..3).times {@skip_years << $rng.rand(2010..2020)}
        end
        if flip
            # remove 1..3 months
            $rng.rand(1..3).times {@skip_months << $rng.rand(1..12)}
        end
    end

    def is_ok(ts)
        year = ts[0..3]
        month = ts[5..6]
        return !@skip_years.include?(year) && !@skip_months.include?(month)
    end

    def next
        # make sure we don't get duplicate times
        while true
            ts = Time.at(@start + $rng.rand * (@end - @start)).strftime("%Y-%m-%d %H:%M:%S")
            if is_ok(ts) && !@cache.include?(ts)
                @cache.add(ts)
                return ts
            end
        end
    end
end

class Weapon
    def initialize(id, name, damage_profile, tohit_adjusted=false)
        @id = id
        @name = name
        @tohit = $rng.rand(0.33..0.75).round(2)
        @tohit_adjusted = 0
        if tohit_adjusted
            @tohit_adjusted = $rng.rand(0.03..0.10).round(2)
            @tohit_adjusted *= -1 if $rng.rand > 0.5
        end
        @damage_profile = damage_profile
        if damage_profile == :minmax
            @mindamage = $rng.rand(1..4)
            @maxdamage = @mindamage + $rng.rand(4..20)
        else
            # convert :_3d8 to mindamage 3, maxdamage 24 (i.e. 3*8)
            @mindamage = damage_profile[1].to_i
            @maxdamage = @mindamage * damage_profile[3..].to_i
        end
    end
  
    def id
        return @id
    end
  
    def to_sql
        return "(#{@id}, '#{@name}', #{@tohit + @tohit_adjusted}, #{@mindamage}, #{@maxdamage})"
    end
  
    def hit
        return $rng.rand < @tohit ? 1 : 0
    end
  
    def damage
        if @damage_profile == :minmax
            return $rng.rand(@mindamage..@maxdamage)
        else
            num = @damage_profile[1].to_i
            die = @damage_profile[3..].to_i
            dam = 0
            num.times do
                dam += $rng.rand(1..die)
            end
            return dam
        end
    end
end


def remove(array, num)
    num.times do
        array.delete_at($rng.rand(0..array.length))
     end
    return array
end

def sampleprob(array, fifty=false)
    # just put each value in there a different number of times
    if fifty
        # one value is 50, the rest are 1.
        probs = [1] * array.length
        probs[$rng.rand(0...array.length)] = 50
        return probs
    else
        # from 1 to 10 times, put each value in there
        probs = []
        array.length.times do
            probs << $rng.rand(1..10)
        end
    end
end


class Ninja
    def initialize(id, name, weapons, num_ninjas)
        # weapons is a hash from pk to the weapon
        # num_ninjas is just the number of ninjas. To create an attack, we
        #      only need their PKs, no other info about the ninjas
        @id = id
        @name = name
        # date picker
        @datetime = TimeMaker.new

        @weapons = weapons

        # weapon list (by primary key, starting at 1)
        @weaponids = *(1..weapons.size)
        # ninjas list (by primary key, starting at 1)
        @ninjaids = *(1..num_ninjas)

        # remove self from ninjas
        @ninjaids.delete(@id)

        # 1/2 chance to remove 1-3 ninjas from attack list
        remove(@ninjaids, $rng.rand(1..3)) if flip

        if flip
            # attack 1-3 ninjas more often than everyone else
            $rng.rand(1..3).times do
                $rng.rand(1..4).times do
                    @ninjaids << @ninjaids.sample(random: $rng)
                end
            end
        else
            if flip
                # gaussian attack profile
                @ninjaids = gauss_profile(@ninjaids)
            else
                # gaussian for n-1, one ninja is 50% of attacks
                @ninjaids = frenemy(@ninjaids)
            end
        end

        # weapon picker
        if flip
            # choose 1-3 weapons more than the others
            $rng.rand(1..3).times do
                $rng.rand(1..4).times do
                    @weaponids << @weaponids.sample(random: $rng)
                end
            end
        else
            if flip
                # gaussian weapon choice profile
                @weaponids = gauss_profile(@weaponids)
            else
                # gaussian for n-1, one weapon is 50% usage
                @weaponids = frenemy(@weaponids)
            end
        end
    end

    def ninjaids
        return @ninjaids
    end

    def attack
        # return tuple of ninja_id and weapon_id
        defender = @ninjaids.sample(random: $rng)
        weapon_id = @weaponids.sample(random: $rng)
        weapon = @weapons[weapon_id]
        hit = weapon.hit
        damage = 0
        damage = weapon.damage if hit == 1
        time = @datetime.next
        return "(#{@id}, #{defender}, '#{time}', #{weapon_id}, #{hit}, #{damage})"
    end

    def to_sql
        return "(#{@id}, '#{@name}')"
    end
end

def create_ninjas_table(ninjas)
    return "DROP TABLE IF EXISTS ninja;
CREATE TABLE ninja (
  id integer PRIMARY KEY,
  name text
);
INSERT INTO ninja (id, name)
VALUES
" + ninjas.values.collect{ |n| n.to_sql}.join(",\n") + ";"
end

def create_weapons_table(weapons)
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
  weapons.values.collect{ |w| w.to_sql}.join(",\n") + ";"
end

def create_attacks_table(attacks)
    return "
DROP TABLE IF EXISTS attack;
CREATE TABLE attack (
  attacker_id integer,
  defender_id integer,
  ttime date,
  weapon_id integer,
  success integer,
  damage integer,
  PRIMARY KEY(attacker_id, defender_id, ttime)
);
CREATE INDEX ix_attacker ON attack (attacker_id);
CREATE INDEX ix_defender ON attack (defender_id);
CREATE INDEX ix_ttime ON attack (ttime);
INSERT INTO attack (attacker_id, defender_id, ttime, weapon_id, success, damage)
VALUES\n" + attacks.join(",\n") + "\n"
end


def main(num_attacks=10000, name_file=nil)
    # create weapons
    weapon_names = ['katana', 'bo stick', 'shuriken', 'nunchaku', 'blowgun',
        'wakizashi', 'quarterstaff', 'harsh words', 'sai', 'kakute',
        'naginate', 'finger of death', 'atomic leg drop'
    ]
    
    # remove between 0 and 4 weapons
    remove(weapon_names, $rng.rand(0..4))
    # now shuffle
    weapon_names.shuffle(random: $rng)

    weapons = Hash.new
    weapon_names.each_with_index do |name, i|
        weapons[i+1] = Weapon.new(i+1, name, $profiles.sample(random: $rng), flip)
    end

    # create ninjas
    if name_file != nil
        ninja_names = File.open(name_file, "r").read.split("\n")
    else
        ninja_names = ['alicia', 'bob', 'carlos', 'deandre', 'erika', 'fatima', 
            'gina', 'hai', 'ibrahim', 'jess', 'kiva', 'leonardo',
            'mohammed', 'nana', 'oscar', 'petri', 'quianna',
            'romeo', 'salvador', 'thu', 'uma', 'violet', 'wu', 'xochitl', 'yasmin', 'zerubabel']
    end
    remove(ninja_names, $rng.rand(8..12))
        
    ninjas = Hash.new
    ninja_names.each_with_index do |name, i|
        # Pass: weapons hash
        # num_ninjas
        # id and name
        # weapon choice profile and ninja attack profile get created in constructor
        ninjas[i+1] = Ninja.new(i+1, name, weapons, ninja_names.size)
    end

    attacks = Array.new
    num_attacks.times do 
        ninja = ninjas.values.sample(random: $rng)
        attacks << ninja.attack
    end

    
    puts create_ninjas_table(ninjas)
    puts create_weapons_table(weapons)
    puts create_attacks_table(attacks)


end

main(num_rows, name_file)