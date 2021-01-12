$rng = Random.new
$profiles = [:minmax, :_1d6, :_2d6, :_3d6, :_1d8, :_2d8, :_3d8, :_1d10, :_2d10]

class Weapon
    def initialize(id, name, damage_profile, tohit_adjusted=false)
        @id = id
        @name = name
        @tohit = $rng.rand(0.15..0.85).round(2)
        @tohit_adjusted = 0
        if tohit_adjusted
            @tohit_adjusted = $rng.rand(0.03..0.10).round(2)
            @tohit_adjusted *= -1 if $rng.rand > 0.5
        end
        @damage_profile = damage_profile
        if damage_profile = :minmax
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

=begin
    * create array of weapons
    * create array of ninjas -- must have attack and weapon usage probabilities
    * give each ninja a date/time picker
=end


class TimeMaker
    def initialize
        @cache = Set.new
        @years = *(2010..2020)
        @months = *(1..12)
        @days = *(1..28)
        @hours = *(0..23)
        @years = remove(@years, $rng(1..3)) if $rng.rand > 0.5
        @months = remove(@years, $rng(1..6)) if $rng.rand > 0.5
        # TODO: use cycle/next to get 12 hours starting at a random time
    end

    def makedatetime
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
