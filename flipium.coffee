# ========================================================================= #
#                                                                           #
#                                FLIPVIEW                                   #
#                                                                           #
# ========================================================================= #  

Flipium = {}

Flipium.createFlipView = (opt={}) ->
  
  flipView = Ti.UI.createView
    width: 320
    height: 460
    top: 0
    
    flipping: 0
    currentPage: 1
    iphone: (Ti.Platform.osname == "iphone")
    android: (Ti.Platform.osname == "android")
    
    duration: 500
    wholeDuration: true
    
    horizontal: false
    images: []
    startPage: 1
    path: "" 
    cacheOnLoad: false
    distance: 1000
    
    offsetTop: 0
    offsetLeft: 0
        
    construct: ->

      for key, value of opt
        @[key] = value

      # Booleans to integers (for Android Java)
      @hh = if @horizontal then 1 else 0
      @vv = if @horizontal then 0 else 1      
      
      # ========================================================================= #
      #   MATRICES                                                                #
      # ========================================================================= #
  
      if @android
        @reset = Ti.UI.create2DMatrix()      
        @flipUp       = @reset.scale(@vv, @hh)
        @flipDown     = @reset.scale(@vv, @hh, Math.pow(-1, @hh), Math.pow(-1, @vv))
        @flipBackUp   = @reset.scale(Math.pow(-1, @hh), Math.pow(-1, @vv), @vv, @hh)
        @flipBackDown = @reset.scale(@vv, @hh, 1, 1)
        @flipAround   = @reset.scale(Math.pow(-1, @hh), Math.pow(-1, @vv))
      else
        @reset = Ti.UI.iOS.create3DMatrix()
        @reset.setM34 -1/@distance
        @flipUp     = @reset.rotate(Math.pow(-1, @hh)*89.9, @vv, @hh, 0)
        @flipBackUp = @reset.rotate(-Math.pow(-1, @hh)*89.9, @vv, @hh, 0)
        @flipDown   = @reset
        
      # ========================================================================= #
      #   FLIPPERS                                                                #
      # ========================================================================= #

      # Check cache
      if Ti.App.Properties.getBool("FlipCached", false)
        Ti.API.info "Reading flipcache"
        @path = Ti.Filesystem.applicationDataDirectory + "/flipcache/"
      else if @cacheOnLoad
        @cacheImages()
        Ti.API.info "Using newly cached"
        @path = Ti.Filesystem.applicationDataDirectory + "/flipcache/"
      else
        Ti.API.info "Loading from #{@path}"        

      # Create flippers
      flippers = [Flipium.createFlipper(0, this)]
      flippers.push Flipium.createFlipper(i+1, this) for image, i in @images  
      @flippers = flippers
      @add flippers[i] for i in [(flippers.length-1)..0] # Reverse hack for android

      # Set flipper 0
      @flippers[0].swapImg()
      @flippers[0].wrap.transform = @flipDown
      @flippers[0].shadow.opacity = 0
      
      @totalPages = @images.length
      
      # Flip to starting page
      flipToStartPage = =>
        if @currentPage < @startPage
          @flippers[@currentPage].flip(0)
          @currentPage += 1
        else
          clearInterval @startTimer

      if @currentPage < @startPage
        @startTimer = setInterval(flipToStartPage, @duration/3)

      # Offset flippers
      @width = @width + @offsetLeft
      @height = @height + @offsetTop

      return this
          
    # ========================================================================= #
    #   CROP & CACHE IMAGE                                                      #
    # ========================================================================= #

    # Edit for horizontalism

    cacheImages: ->
      Ti.API.info "Caching images to flipcache"
      Ti.App.Properties.setBool("FlipCached", true)
      @cacheImg(image, i+1) for image, i in @images

    cacheImg: (image, index) ->
      appDir = Ti.Filesystem.applicationDataDirectory
      dir = Ti.Filesystem.getFile(appDir, "flipcache")
      dir.createDirectory()      
      f = Ti.Filesystem.getFile(appDir + "/flipcache/", "img_#{index}_#{if @hh then "l" else "t"}.png")
      f.write @cropImg(image, "top")
      f = Ti.Filesystem.getFile(appDir + "/flipcache/", "img_#{index}_#{if @hh then "r" else "b"}.png")
      f.write @cropImg(image, "bottom")
      f = null
      
    cropImg: (image, position) ->
      crop = Ti.UI.createView
        width: @width *(2-@android) /(1+@hh)
        height: @height *(2-@android) /(1+@vv)
        top: 0
        left: 0
      img = Ti.UI.createImageView
        image: @path + image
        width: @width *(2-@android)
        height: @height *(2-@android)
        top: 0
        left: 0        
      crop.add img
      if position == "bottom" && @hh
        img.left = -@width/2 *(2-@android)
      else if position == "bottom" && not @hh
        img.top = -@height/2 *(2-@android)
      
      unless @android
        return crop.toImage()
      else
        postImg = Ti.UI.createImageView
          image: crop.toImage()
        return postImg.toBlob()
          
    # ========================================================================= #
    #   HELPER METHODS                                                          #
    # ========================================================================= #

    current: ->
      @flippers[@currentPage]

    prev: ->
      if @currentPage >= 0
        @flippers[@currentPage - 1]
      else
        return false
                  
  return flipView.construct()


# ========================================================================= #
#                                                                           #
#                                FLIPPER                                    #
#                                                                           #
# ========================================================================= #  

Flipium.createFlipper = (index, ff) ->

  flipper = Ti.UI.createView
    width: ff.width
    height: ff.height
    top: ff.offsetTop
    left: ff.offsetLeft
    zIndex: -index
    flipping: 0

  # ========================================================================= #
  #   ELEMENTS                                                                #
  # ========================================================================= #  

    img_b: Ti.UI.createImageView
      image: ff.path + "img_#{index}_#{if ff.hh then "r" else "b"}.png"
      width: ff.width /(1+ff.hh)
      height: ff.height /(1+ff.vv)
      top: 0
      left: 0

    img_t: Ti.UI.createImageView
      image: ff.path + "img_#{index+1}_#{if ff.hh then "l" else "t"}.png"
      width: ff.width /(1+ff.hh)
      height: ff.height /(1+ff.vv)
      top: 0
      left: 0
    
    wrap: Ti.UI.createView
      width: ff.width /(1+ff.hh)
      height: ff.height /(1+ff.vv)
      top: if ff.hh then 0 else ff.height/2
      left: if ff.hh then ff.width/2 else 0
      anchorPoint: if ff.hh then { x: 0, y: 0.5 } else { x: 0.5, y: 0 }

    darken: Ti.UI.createView
      backgroundColor: "#000"
      width: ff.width /(1+ff.hh)
      height: ff.height /(1+ff.vv)
      top: 0
      left: 0
      opacity: 0

    shadow: Ti.UI.createView
      backgroundColor: "#000"
      width: ff.width /(1+ff.hh)
      height: ff.height /(1+ff.vv)
      top: if ff.hh then 0 else ff.height/2
      left: if ff.hh then ff.width/2 else 0
      opacity: 1
      zIndex: -1
            
    duration: ff.duration
    index: index
    
    prev: ->
      ff.flippers[@index-1] if @index > 0
    
    construct: ->

      # ========================================================================= #
      #   ANIMATIONS                                                              #
      # ========================================================================= #
  
      @flipUpAnim = Ti.UI.createAnimation
        transform: ff.flipUp
        curve: Ti.UI.iOS.ANIMATION_CURVE_EASE_OUT unless ff.android
      @flipDownAnim = Ti.UI.createAnimation
        transform: ff.flipDown
        curve: Ti.UI.iOS.ANIMATION_CURVE_EASE_OUT unless ff.android
      @flipBackUpAnim = Ti.UI.createAnimation
        transform: ff.flipBackUp
        curve: Ti.UI.iOS.ANIMATION_CURVE_EASE_OUT unless ff.android
      @flipBackDownAnim = Ti.UI.createAnimation
        transform: if ff.android then ff.flipBackDown else ff.flipDown
        curve: Ti.UI.iOS.ANIMATION_CURVE_EASE_OUT unless ff.android
      @shadowOutAnim = Ti.UI.createAnimation
        opacity: 0
        curve: Ti.UI.iOS.ANIMATION_CURVE_EASE_OUT unless ff.android
      @shadowInAnim = Ti.UI.createAnimation
        opacity: 0.75
        curve: Ti.UI.iOS.ANIMATION_CURVE_EASE_IN unless ff.android
      @darkenOutAnim = Ti.UI.createAnimation
        opacity: 0
        curve: Ti.UI.iOS.ANIMATION_CURVE_EASE_OUT unless ff.android
      @darkenInAnim = Ti.UI.createAnimation
        opacity: 0.08
        curve: Ti.UI.iOS.ANIMATION_CURVE_EASE_IN unless ff.android
         
      # ========================================================================= #
      #   ANIMATION COMPLETES                                                     #
      # ========================================================================= #

      @flipUpAnim.addEventListener "complete", =>
        ff.flipping -= 1
        @flipping -= 1
        if @flipping == 0
          @swapImg() if not @flipped
          @flip(0.5)
      
      @flipBackUpAnim.addEventListener "complete", =>
        ff.flipping -= 1
        @flipping -= 1
        if @flipping == 0
          @swapImg(true) if @flipped
          @flip(0.5, true)
        
      @flipDownAnim.addEventListener "complete", =>
        ff.flipping -= 1
        @flipping -= 1
        @darken.opacity = 0
        @shadow.opacity = 0

      @flipBackDownAnim.addEventListener "complete", =>
        ff.flipping -= 1
        @flipping -= 1
        @darken.opacity = 0
        @prev().darken.opacity = 0 if @prev()
        
      # ========================================================================= #
      #   ADD ELEMENTS                                                            #
      # ========================================================================= #

      @wrap.add @img_t
      @img_t.visible = false

      @wrap.add @img_b
      @wrap.add @darken
      @add @shadow
      @add @wrap

      return this

    # ========================================================================= #
    #   FLIP METHODS                                                            #
    # ========================================================================= #

    flip: (y, reverse) ->
      if ff.android
        @shadow.opacity = if y <= 0.5 then 0.6 - 3*Math.pow(y, 2) else 0
        @darken.opacity = 0.08-0.32*Math.pow(y-0.5, 2)
        if @prev()
          @prev().darken.opacity = if y >= 0.5 then 3*Math.pow(y-0.5, 2) else 0
              
      if y < 0.5 && not reverse
        # Flip up
        dur = @duration / 2
        dur = dur * (1 - Math.pow(2*y, 0.625))
        if ff.android
          @flipUpAnim.transform = ff.reset.scale(1-2*y*ff.hh, 1-2*y*ff.vv, ff.vv, ff.hh)
        @flipUpAnim.duration    = dur
        @shadowOutAnim.duration = dur
        @darkenInAnim.duration  = dur
        @wrap.animate   @flipUpAnim
        @shadow.animate @shadowOutAnim
        @darken.animate @darkenInAnim
            
      else if y >= 0.5 && not reverse
        # Flip down
        dur = @duration / 2 
        unless ff.wholeDuration
          dur = dur * (1 - Math.pow(2*y-1, 0.625))
          dur = dur * 2 if @index == 0
        if ff.android
          @flipDownAnim.transform = ff.reset.scale(1-2*y*ff.hh, 1-2*y*ff.vv, Math.pow(-1, ff.hh), Math.pow(-1, ff.vv))          
        @flipDownAnim.duration  = dur
        @darkenOutAnim.duration = dur
        @wrap.animate   @flipDownAnim
        @darken.animate @darkenOutAnim
        if @prev()        
          @prev().shadowInAnim.duration = dur
          @prev().darken.animate @prev().shadowInAnim
          if ff.android # Android animation hack
            @prev().shadow.animate { opacity: 0 }
            @prev().animate { left: 0, duration: dur }

      else if y > 0.5 && reverse
        # Flip back up
        dur = @duration / 2 * Math.pow(2*y-1, 0.625)
        if ff.android
          @flipBackUpAnim.transform = ff.reset.scale(1-2*y*ff.hh, 1-2*y*ff.vv, ff.vv, ff.hh)       
        @flipBackUpAnim.duration = dur
        @darkenInAnim.duration   = dur
        @wrap.animate   @flipBackUpAnim
        @darken.animate @darkenInAnim
        if @prev()
          @prev().shadowOutAnim.duration = dur
          @prev().darken.animate @prev().shadowOutAnim
          if ff.android # Android animation hack
            @prev().shadow.animate { opacity: 0 }
            @prev().animate { left: 0, duration: dur }            
      
      else if y <= 0.5 && reverse
        # Flip back down
        dur = @duration / 2 
        unless ff.wholeDuration
          dur = dur * Math.pow(2*y, 0.625)
          dur = dur * 2 if @index == ff.totalPages
        if ff.android
          @flipBackDownAnim.transform = ff.reset.scale(1-2*y*ff.hh, 1-2*y*ff.vv, 1, 1)        
        @flipBackDownAnim.duration = dur
        @shadowInAnim.duration     = dur
        @darkenOutAnim.duration    = dur
        @wrap.animate   @flipBackDownAnim
        @shadow.animate @shadowInAnim
        @darken.animate @darkenOutAnim
        
      ff.flipping += 1
      @flipping += 1
      
    
    swapImg: (reverse) ->
      if reverse 
        @img_t.visible = false
        @img_b.visible = true
        if ff.android
          @img_t.transform = ff.reset
          @img_t.top = 0
          @img_t.left = 0
        else
          @wrap.anchorPoint = if ff.hh then { x: 0, y: 0.5 } else { x: 0.5, y: 0 }
          @wrap.transform = ff.flipUp
          if ff.hh
            @wrap.left = ff.width/2
          else
            @wrap.top = ff.height/2          
        @zIndex = -@index
        
      else
        @img_t.visible = true
        @img_b.visible = false
        if ff.android
          @img_t.transform = ff.flipAround
          if ff.hh
            @img_t.left = ff.width/2
          else
            @img_t.top = ff.height/2
        else
          @wrap.anchorPoint = if ff.hh then { x: 1, y: 0.5 } else { x: 0.5, y: 1 }
          @wrap.transform = ff.flipBackUp
          if ff.hh
            @wrap.left = 0
          else
            @wrap.top = 0
        @zIndex = @index
      @flipped = !reverse 
      
    stopFlipping: ->
      if @flipped
        y = if ff.android then 0.8 else 0.7
      else
        y = if ff.android then 0.2 else 0.3
      darken_to = 0.08 - 0.32*Math.pow(y-0.5, 2)
      shadow_to = if y <= 0.5 then 2.27*Math.pow(0.5-y, 1.6) else 0
      prev_to = if y >= 0.5 then 2.27*Math.pow(y-0.5, 1.6) else 0
      @darken.animate { opacity: darken_to, duration: 1 }
      @shadow.animate { opacity: shadow_to, duration: 1 }
      @prev().darken.animate { opacity: prev_to, duration: 1 } if @prev()

      if ff.android 
        @wrap.animate { opacity: 1, duration: 1 }
      else
        if y < 0.5
          dragMatrix = ff.reset.rotate(Math.pow(-1, ff.hh)*y*180, ff.vv, ff.hh, 0)  
        else
          dragMatrix = ff.reset.rotate(-Math.pow(-1, ff.hh)*(1-y)*180, ff.vv, ff.hh, 0)              
        @wrap.animate { transform: dragMatrix, duration: 1 }

      return y

  return flipper.construct()


# ========================================================================= #
#                                                                           #
#                               DRAGVIEW                                    #
#                                                                           #
# ========================================================================= #  

Flipium.createDragView = (ff, opt={}) ->

  dragView = Ti.UI.createView
    width: ff.width
    height: ff.height
    top: 0
        
    dragDistance: 230
    dragThreshold: 0.5
    initialDrag: 10
    tapThreshold: 5
    topLimit: 0.7
    bottomLimit: 0.3

    construct: ->

      for key, value of opt
        @[key] = value
        
      if ff.android
        @topLimit = Math.pow(@topLimit, 0.625)
        @bottomLimit = Math.pow(@bottomLimit, 1.6)
      
      # ========================================================================= #
      #   TOUCH GESTURES                                                          #
      # ========================================================================= #  

      @addEventListener "touchstart", (e) ->
        @startY = if ff.hh then e.x else e.y
        @startX = if ff.hh then e.y else e.x
        ff.dragging = true
      
      @addEventListener "touchmove", (e) ->
        ey = if ff.hh then e.x else e.y
        ex = if ff.hh then e.y else e.x
        
        # Target a flipper
        if Math.abs(@startY - ey) > @initialDrag && not @dir
          if Math.abs(@startX - ex) < 1.2 * Math.abs(@startY - ey)
            if ey > @startY
              @dir = "down"
              @flipper = ff.prev()
            else
              @dir = "up"
              @flipper = ff.current()
      
            # Stop flip
            if @flipper.flipping > 0
              y = @flipper.stopFlipping()
              @startY = (y - (@dir == "down")) * @dragDistance + ey

            @flipper.flipping += 1
      
            @_y = ey


        if @dir
          # Set y movement
          @y = (@dir == "down") + (@startY - ey)/@dragDistance
          @y = 0 if @y < 0
          @y = 1 if @y > 1
          
          # Page limits
          @y = @topLimit if @flipper.index == 0 && @y < @topLimit
          @y = @bottomLimit if @flipper.index == ff.totalPages && @y > @bottomLimit
          
          # # Time out inertia
          storeY = =>
            @_y = ey
          @timer = setTimeout(storeY, 200)
      
          # Rotate flipper
          darken_to = 0.08-0.32*Math.pow(@y-0.5,2)
          shadow_to = if @y <= 0.5 then 2.27*Math.pow(0.5-@y, 1.6) else 0
          prev_to = if @y >= 0.5 then 2.27*Math.pow(@y-0.5, 1.6) else 0
          if ff.android
            if ff.hh
              dragMatrix = ff.reset.scale(1-2*@y, 1)
            else
              dragMatrix = ff.reset.scale(1, 1-2*@y)            
            @flipper.darken.animate { opacity: darken_to }
            @flipper.shadow.animate { opacity: shadow_to }
            @flipper.prev().darken.animate { opacity: prev_to } if @flipper.prev()
          else
            @flipper.darken.opacity = darken_to
            @flipper.shadow.opacity = shadow_to
            @flipper.prev().darken.opacity = prev_to if @flipper.prev()
            if @y < 0.5
              dragMatrix = ff.reset.rotate(Math.pow(-1, ff.hh)*@y*180, ff.vv, ff.hh, 0)  
            else
              dragMatrix = ff.reset.rotate(-Math.pow(-1, ff.hh)*(1-@y)*180, ff.vv, ff.hh, 0)              
          @flipper.wrap.transform = dragMatrix
    
          # Flip image over or back
          if @y > 0.5 && not @flipper.flipped
            @flipper.swapImg()
          else if @y < 0.5 && @flipper.flipped
            @flipper.swapImg(true)                    
      
      
      @addEventListener "touchend", (e) ->
        clearInterval @timer if @timer
        ey = if ff.hh then e.x else e.y
        ex = if ff.hh then e.y else e.x
        
        y2 = Math.pow(@startY - ey, 2)
        x2 = Math.pow(@startX - ex, 2)
        
        if Math.pow(y2 + x2, 0.5) < 5
          @fireEvent "tap", e
        
        else if @dir
          if @_y - ey > @initialDrag && @flipper.index < ff.totalPages
            @flipper.flip(@y)
            ff.currentPage += (@dir == "up")
          else if ey - @_y > @initialDrag && @flipper.index > 0
            @flipper.flip(@y, true)          
            ff.currentPage -=  (@dir == "down")
          else if @y > @dragThreshold
            @flipper.flip(@y)
            ff.currentPage += (@dir == "up")
          else
            @flipper.flip(@y, true)
            ff.currentPage -= (@dir == "down")
                      
          @flipper.flipping -= 1

          @inertia = ff.dragging = false
          @y = 0
          @dir = null
                
      return this
  
  return dragView.construct()

module.exports = Flipium