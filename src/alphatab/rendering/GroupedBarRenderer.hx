package alphatab.rendering;
import alphatab.model.Bar;
import alphatab.model.Beat;
import alphatab.model.Voice;
import alphatab.platform.ICanvas;
import alphatab.platform.model.Color;
import alphatab.rendering.glyphs.BeatContainerGlyph;
import alphatab.rendering.glyphs.BeatGlyphBase;
import alphatab.rendering.glyphs.ISupportsFinalize;
import alphatab.rendering.glyphs.SpacingGlyph;
import alphatab.rendering.glyphs.VoiceContainerGlyph;
import alphatab.rendering.layout.ScoreLayout;
import alphatab.rendering.staves.BarSizeInfo;
import haxe.ds.IntMap;

/**
 * This BarRenderer has 3 different groups which cna store glyphs:
 *  - PreBeatGlyphs : Those glyphs are aligned left to right before the first glyph which represents a beat
 *  - BeatGlyphs : Each of those glyphs represents one beat. They are aligned left to right.
 *  - PostBeatGlyphs : Those glyphs are aligned left to right after the last beat glyph
 */
class GroupedBarRenderer extends BarRendererBase
{
	public static inline var KEY_SIZE_PRE = "PRE";
	public static inline var KEY_SIZE_POST = "POST";
	
	private var _preBeatGlyphs:Array<Glyph>;
    private var _voiceContainers:IntMap<VoiceContainerGlyph>;
	private var _postBeatGlyphs:Array<Glyph>;
	
    private var _biggestVoiceContainer:VoiceContainerGlyph;
    
	public function new(bar:Bar) 
	{
		super(bar);
		_preBeatGlyphs = new Array<Glyph>();
        _voiceContainers = new IntMap<VoiceContainerGlyph>();
	    _postBeatGlyphs = new Array<Glyph>();
	}
	
	public override function doLayout():Void 
	{
		createPreBeatGlyphs();
		createBeatGlyphs();
		createPostBeatGlyphs();
        for (c in _voiceContainers)
        {
            c.doLayout();
        }
		updateWidth();
	}
	
	private function updateWidth()
	{
		width = getPostBeatGlyphsStart();
		if (_postBeatGlyphs.length > 0) 
		{
			width += _postBeatGlyphs[_postBeatGlyphs.length - 1].x + _postBeatGlyphs[_postBeatGlyphs.length - 1].width;
		}
        for (c in _voiceContainers)
        {
            if (_biggestVoiceContainer == null || c.width > _biggestVoiceContainer.width)
            {
                _biggestVoiceContainer = c;
            }
        }
	}
	
	public override function registerMaxSizes(sizes:BarSizeInfo):Void 
	{
		var preSize = getBeatGlyphsStart();
		if (sizes.getSize(KEY_SIZE_PRE) < preSize)
		{
			sizes.setSize(KEY_SIZE_PRE, preSize);			
		}
		
        for (c in _voiceContainers)
        {
            c.registerMaxSizes(sizes);
        }
		
		var postSize:Int;
		if (_postBeatGlyphs.length == 0)
		{
			postSize = 0;
		}
		else
		{
			postSize = _postBeatGlyphs[_postBeatGlyphs.length - 1].x + _postBeatGlyphs[_postBeatGlyphs.length - 1].width;
		}
		if (sizes.getSize(KEY_SIZE_POST) < postSize)
		{
			sizes.setSize(KEY_SIZE_POST, postSize);
		}
		
		if (sizes.fullWidth < width)
		{
			sizes.fullWidth = width;
		}
	}
	
	public override function applySizes(sizes:BarSizeInfo):Void 
	{
		// if we need additional space in the preBeat group we simply
		// add a new spacer
		var preSize = sizes.getSize(KEY_SIZE_PRE);
		var preSizeDiff = preSize - getBeatGlyphsStart();
		if (preSizeDiff > 0)
		{
			addPreBeatGlyph(new SpacingGlyph(0, 0, preSizeDiff));
		}
		
		// on beat glyphs we apply the glyph spacing
        for (c in _voiceContainers)
        {
            c.applySizes(sizes);
        }
		
		// on the post glyphs we add the spacing before all other glyphs
		var postSize = sizes.getSize(KEY_SIZE_POST);
		var postSizeDiff:Int;
		if (_postBeatGlyphs.length == 0)
		{
			postSizeDiff = 0;
		}
		else
		{
			postSizeDiff =  postSize - (_postBeatGlyphs[_postBeatGlyphs.length - 1].x + _postBeatGlyphs[_postBeatGlyphs.length - 1].width);
		}
		
		if (postSizeDiff > 0)
		{
			_postBeatGlyphs.insert(0, new SpacingGlyph(0, 0, postSizeDiff));
			for (i in 0 ... _postBeatGlyphs.length)
			{
				var g = _postBeatGlyphs[i];
				g.x = i == 0 ? 0 : _postBeatGlyphs[_postBeatGlyphs.length - 1].x + _postBeatGlyphs[_postBeatGlyphs.length - 1].width;
				g.index = i;
				g.renderer = this;
			}
		}
		
		updateWidth();
        
	}
	
	private function addGlyph<T : (Glyph)>(c:Array<T>, g:T)
	{
        isEmpty = false;
		g.x = c.length == 0 ? 0 : (c[c.length - 1].x + c[c.length - 1].width);
		g.index = c.length;
		g.renderer = this;
		g.doLayout();
		c.push(g);
	}
	
	private function addPreBeatGlyph(g:Glyph)
	{
		addGlyph(_preBeatGlyphs, g);
	}
	
	private function addBeatGlyph(g:BeatContainerGlyph)
	{
        getOrCreateVoiceContainer(g.beat.voice.index).addGlyph(g);
	}
    
    private function getOrCreateVoiceContainer(voiceIndex:Int)
    {
        var c:VoiceContainerGlyph;
        if (!_voiceContainers.exists(voiceIndex))
        {
            c = new VoiceContainerGlyph(0, 0, voiceIndex);
            c.renderer = this;
            _voiceContainers.set(voiceIndex, c);
        }
        else
        {
            c = _voiceContainers.get(voiceIndex);
        }
        return c;
    }
    
    public inline function getBeatContainer(voice:Int, beat:Int) :BeatContainerGlyph
    {
        return getOrCreateVoiceContainer(voice).beatGlyphs[beat];
    }    
    
    public inline function getPreNotesPosition(voice:Int, beat:Int)
    {
        return getBeatContainer(voice,beat).preNotes;
    }
    
    public inline function getOnNotesPosition(voice:Int, beat:Int)
    {
        return getBeatContainer(voice,beat).onNotes;
    }
    
    public inline function getPostNotesPosition(voice:Int, beat:Int)
    {
        return getBeatContainer(voice,beat).postNotes;
    }
    
	
	private function addPostBeatGlyph(g:Glyph)
	{
		addGlyph(_postBeatGlyphs, g);
	}
	
	private function createPreBeatGlyphs()
	{
		
	}
	
	private function createBeatGlyphs()
	{
		
	}
	
	private function createPostBeatGlyphs()
	{
		
	}
	
	public function getPreBeatGlyphStart() : Int
	{
		return 0;
	}
	
	public function getBeatGlyphsStart() : Int
	{
		var start = getPreBeatGlyphStart();
		if (_preBeatGlyphs.length > 0)
		{
			start += _preBeatGlyphs[_preBeatGlyphs.length - 1].x + _preBeatGlyphs[_preBeatGlyphs.length - 1].width;
		}
		return start;
	}
	
	public function getPostBeatGlyphsStart() : Int
	{
		var start = getBeatGlyphsStart();
        var offset:Int = 0;
        for (c in _voiceContainers)
        {
            if (c.width > offset)
            {
                offset = c.width;
            }
            //if (c.beatGlyphs.length > 0)
            //{
            //    var coff = c.beatGlyphs[c.beatGlyphs.length - 1].x + c.beatGlyphs[c.beatGlyphs.length - 1].width;
            //    if (coff > offset)
            //    {
            //        offset = coff;
            //    }
            //}
        }
		
		return start + offset;		
	}
		
	public override function applyBarSpacing(spacing:Int):Void 
	{
        width += spacing;     
        
        for (c in _voiceContainers)
        {
            var toApply = spacing;
            if (_biggestVoiceContainer != null)
            {
                toApply += _biggestVoiceContainer.width - c.width; 
            }
            c.applyGlyphSpacing(toApply);
        }
	}
	
	public override function finalizeRenderer(layout:ScoreLayout):Void 
	{
        for (c in _voiceContainers)
        {
            c.finalizeGlyph(layout);
        }
	}
	
	public override function paint(cx:Int, cy:Int, canvas:ICanvas)
	{
        paintBackground(cx, cy, canvas);
		
		var glyphStartX = getPreBeatGlyphStart();
		for (g in _preBeatGlyphs)
		{
			g.paint(cx + x + glyphStartX, cy + y, canvas);
		}		
		
		glyphStartX = getBeatGlyphsStart();
        for (c in _voiceContainers)
        {
            c.paint(cx + x + glyphStartX, cy + y, canvas);
        }

		glyphStartX = getPostBeatGlyphsStart();
		for (g in _postBeatGlyphs)
		{
			g.paint(cx + x + glyphStartX, cy + y, canvas);
		}	
	}
    
	public function paintBackground(cx:Int, cy:Int, canvas:ICanvas)
	{
		
	}
}