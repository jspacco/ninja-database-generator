require 'set'

$rng = Random.new
$profiles = [:minmax, :_1d6, :_2d6, :_3d6, :_1d8, :_2d8, :_3d8, :_1d10, :_2d10]

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


class TimeMaker
    def initialize
        @cache = Set.new
        @years = *(2010..2020)
        @months = *(1..12)
        @days = *(1..30)
        @hours = *(0..23)
        # 50% chance to randomly remove 1 to 3 years
        @years = remove(@years, $rng.rand(1..3)) if $rng.rand > 0.5
        # 50% chance to randomly remove 1 to 6 months
        @months = remove(@years, $rng.rand(1..6)) if $rng.rand > 0.5
        # TODO: use cycle/next to get 12 hours starting at a random time
    end

    def next
        # make sure we don't get duplicate times
        while true
            ts = "%d-%02d-%02d %02d:%02d:%02d" % [
                @years.sample,
                @months.sample,
                @days.sample,
                @hours.sample,
                $rng.rand(0...60),
                $rng.rand(0...60)
            ]
            if !@cache.include? ts
                @cache.add(ts)
                return ts
            end
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
    def initialize(id, name, ninjas, weapons)
        @id = id
        @name = name
        # date picker
        @datetime = TimeMaker.new

        @weapons = weapons
        @ninjas = ninjas

        # weapon list (by primary key, starting at 1)
        @weaponids = *(1..weapons.size)
        # ninjas list (by primary key, starting at 1)
        @ninjaids = *(1..ninjas.size)


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

    def attack
        # return tuple of ninja_id and weapon_id
        defender = @ninjaids.sample(random: $rng)
        weapon_id = @weaponids.sample(random: $rng)
        weapon = @weapons[weapon_id]
        hit = weapon.hit
        damage = 0
        damage = weapon.damage if hit == 1
        time = @datetime.next
        #TODO: produce a SQL insert statement
        return "(#{@id}, #{defender}, '#{time}', #{weapon_id}, #{hit}, #{damage})"
    end
end


def main
    $rng = Random.new(1)
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
    ninja_names = ['alicia', 'bob', 'carlos', 'deandre', 'erika', 'fatima', 
        'gina', 'hai', 'ibrahim', 'jess', 'kiva', 'leonardo',
        'mohammed', 'nana', 'oscar', 'petri', 'quianna',
        'romeo', 'salvador', 'thu', 'uma', 'violet', 'wu', 'xochitl', 'yasmin', 'zerubabel']
    remove(ninja_names, $rng.rand(10..16))
    #ninja_names.shuffle(random: $rng)
    
    ninjas = Hash.new
    ninja_names.each_with_index do |name, i|
        # Pass: weapons
        # weapon choice profile
        # ninja attack profile
        ninjas[i+1] = Ninja.new(i+1, name, ninjas, weapons)
        #puts ninjas[i+1].attack
    end

    attacks = Array.new
    100.times do 
        ninja = ninjas.values.sample(random: $rng)
        attacks << ninja.attack
    end
    puts "INSERT INTO attack (attacker_id, defender_id, time, weapon_id, success, damage)\n" +
        "VALUES\n" + attacks.join(",\n") + ';'
end

main