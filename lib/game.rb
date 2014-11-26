require 'gosu'

GOAL_SCORE = 111
END_ROUND_ROLL = 1

def KeyStruct(property_defaults)
  klass = Struct.new(*property_defaults.keys) do
    def initialize(properties = {})
      super()
      self.class.const_get(:DEFAULTS).each do |key, default|
        self[key] = properties.fetch(key) do
          Marshal.load(Marshal.dump(default))
        end
      end
    end
  end

  klass.const_set(:DEFAULTS, property_defaults)
  klass.class_exec(klass, &Proc.new) if block_given?

  klass
end

Player = KeyStruct(name: '', score: 0)
GameState = KeyStruct(
  players: [],
  current_player_idx: nil,
  round: [],
  message: "Please enter the players' names",
) do

  def started?
    current_player_idx != nil
  end

  def finished?
    not winner.nil?
  end

  def winner
    players.find { |p| p.score >= GOAL_SCORE }
  end

  def current_player
    players[current_player_idx]
  end

  def next_player
    players[(current_player_idx + 1) % players.size]
  end

  def round_total
    round.reduce(0, :+)
  end
end

class GameWindow < Gosu::Window
  def initialize
    super(640, 480, false)
    self.caption = 'The Dice Is Right'
    @font = Gosu::Font.new(self, Gosu::default_font_name, 20)

    restart_game
  end

  def needs_cursor?
    true
  end

  def button_down(button)
    if @game.finished?
      case button
      when Gosu::KbReturn then restart_game
      end
    elsif @game.started?
      case button
      when Gosu::KbR then roll_dice
      when Gosu::KbS then end_round(true)
      end
    else
      case button
      when Gosu::KbReturn then add_player
      end
    end
  end

  def draw
    players = @game.players
    unless @game.started?
      caret = (Gosu::milliseconds % 1000 < 500 ? '|' : ' ')
      next_name = self.text_input.text.insert(self.text_input.caret_pos, caret)
      if @game.players.size > 1 && (next_name.strip.length == 0 || next_name == caret)
        next_name += " (Press enter to start game)"
      else
        next_name = next_name
      end
      players += [Player.new(name: next_name)]
    end

    if @game.finished?
      text = "#{@game.winner.name} is the winner!"
      restart_text = "Press return to play again"
      @font.draw(text, (width - @font.text_width(text)) / 2, height/2 - 20, 0)
      @font.draw(restart_text, (width - @font.text_width(restart_text)) / 2, height/2 + 20, 0)
    elsif @game.started?
      @font.draw("#{@game.current_player.name}, [r]oll or [s]top?", 300, 50, 0)
      @font.draw("This round: #{@game.round_total}", 10, height - 10 - @font.height, 0)
    end

    unless @game.finished?
      @font.draw(@game.message, 300, 10, 0)

      players.each_with_index do |p, idx|
        y = 10 + idx * (@font.height + 5)
        score = (@game.started? ? "(#{p.score})" : "")
        @font.draw("Player #{idx+1}: #{p.name} #{score}", 30, y, 0) 
        if idx == @game.current_player_idx
          c = Gosu::Color::WHITE
          draw_triangle(10, y + 5, c, 10, y + @font.height - 5, c, 20, y + @font.height / 2.0, c)
        end
      end
    end
  end

  def roll_dice
    roll = rand(1..6)    
    @game.message = "#{@game.current_player.name} rolled a #{roll}!"

    if roll == END_ROUND_ROLL
      @game.message += " Your turn, #{@game.next_player.name}."
      end_round(false)
    else
      play_sound('dice.mp3')
      @game.round << roll
    end
  end

  def end_round(save_score)
    if save_score
      @game.current_player.score += @game.round_total
    end

    if @game.finished?
      play_sound('chaching.wav')
    elsif save_score
      play_sound('clap.wav')
    else
      play_sound('buzzer.mp3')
    end

    @game.current_player_idx = (@game.current_player_idx + 1) % @game.players.size
    @game.round = []
  end

  def add_player
    name = self.text_input.text.strip
    if name.size == 0
      if @game.players.size > 1
        @game.current_player_idx = 0
        @game.message = "The game starts with #{@game.current_player.name}"
        play_sound('go.wav')
        self.text_input = nil
      end
    else
      @game.players << Player.new(name: name)
      self.text_input.text = ''
      @game.message = "Welcome, #{name}"
    end
  end

  def restart_game
    @game = GameState.new
    self.text_input = Gosu::TextInput.new
  end

  def play_sound(filename, speed=0.9..1.1, volume=1..1)
    sound = Gosu::Sample.new(self, "assets/#{filename}")
    sound.play(rand(volume), rand(speed))
  end
end

GameWindow.new.show
