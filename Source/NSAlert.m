/** <title>NSAlert</title>

   <abstract>Encapsulate an alert panel</abstract>

   Copyright <copy>(C) 1998, 2000, 2004 Free Software Foundation, Inc.</copy>

   Author: Fred Kiefer <FredKiefer@gmx.de>
   Date: July 2004

   GSAlertPanel and alert panel functions implementation
   Author: Richard Frith-Macdonald <richard@brainstorm.co.uk>
   Date: 1998

   GSAlertPanel and alert panel functions cleanup and improvements (scroll view)
   Author: Pascal J. Bourguignon <pjb@imaginet.fr>>
   Date: 2000-03-08

   This file is part of the GNUstep GUI Library.

   This library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Library General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU Library General Public
   License along with this library; see the file COPYING.LIB.
   If not, write to the Free Software Foundation,
   59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*/

#include "config.h"

#include <Foundation/NSBundle.h>
#include <Foundation/NSString.h>
#include "AppKit/NSAlert.h"
#include "AppKit/NSApplication.h"
#include "AppKit/NSBox.h"
#include "AppKit/NSButton.h"
#include "AppKit/NSFont.h"
#include "AppKit/NSHelpManager.h"
#include "AppKit/NSImage.h"
#include "AppKit/NSMatrix.h"
#include "AppKit/NSPanel.h"
#include "AppKit/NSScreen.h"
#include "AppKit/NSScrollView.h"

#include "GNUstepGUI/IMLoading.h"
#include "GNUstepGUI/GMAppKit.h"
#include "GNUstepGUI/GMArchiver.h"


#ifdef ALERT_TITLE
static NSString	*defaultTitle = @"Alert";
#else
static NSString	*defaultTitle = @" ";
#endif

/*

 +--------------------------------------------------------------------------+
 |############################Title bar#####################################|
 +--------------------------------------------------------------------------+
 |       |           |   |    |                                             |
 |  ...........      |   |    |                                             |
 |  :       | :      |   |    |                                             |
 |--:  Icon | :----Title |    |                                             |
 |  :-------|-:          |    |                                             |
 |  :.........:          |    |                                             |
 |                       |    |                                             |
 |-===========================|=============~~~~~~=========================-|
 |                       s    |                                             |
 |                       s    |                                             |
 |    ...................s....|.........................................    |
 |    :Message           s                    s                        ;    |
 |    :                  s                    s                        :    |
 |    :                  s                    s                        :    |
 |----:                  s                    s                        :----|
 |    :~~~~~~~~~~~~~~~~~~s~~~~~~~~~~~~~~~~~~~~s~~~~~~~~~~~~~~~~~~~~~~~~:    |
 |    :                  s                    s                        :    |
 |    :..................s.............................................:    |
 |             |         s                                                  |
 |             |         s +-----------+   +-----------+   +-----------+    |
 |             |         s |  Altern   |---|  Cancel   |---|    OK     |----|
 |             |         s +-----------+   +-----------+   +-----------+    |
 |             |         s      |                 |             |           |
 +--------------------------------------------------------------------------+

    Apart from  the buttons and window  borders, '|' and  '-' mean not
    flexible, while '~' and 's' mean flexible.

    The global  window size  is determined by  the message  text field
    size.  which  is computed with  sizeToFit. However, if  the window
    would become larger  than the screen, then the  message text field
    is replaced with a scroll view containing the text.


    The strategy taken  in this new version of  GSAlertPanel is to let
    the icon,  the title  field and the  line (box view)  being placed
    automatically  by  resizing  the   window,  but  to  always  place
    explicitely the  message field (or  scroll view when  it's needed)
    and  the buttons  (that may  change of  width), the  whole  in the
    sizeToFitIfNeeded  method.  We're  doing  it separately  from  the
    setting  of the elements  (setTitle: ...) because  we also  need to
    recompute the size of the window and position of the elements when
    dearchiving a panel, because  it could be dearchived and displayed
    on a much smaller screen  than originaly created, in which case we
    needed to embed  the message field into a  scroll view, and reduce
    the size of the window.


    Some rules (which are implemented in sizePanelToFit):
    =====================================================


    IF   the messageField is too big either vertically or horizontally and
         would make the window greater than the screen in any direction,
    THEN use a scroll view.


    The width of the window content rect is the minimum of:
      = the width of the content rect of a window filling the screen
      = the maximum of:
        = a minimum width of 362,
        = the messageField width + 2 = MessageHorzMargin,
        = the sum of sizes of the buttons and their interspaces and margins,
        = the sum of sizes of the icon, title and their interspaces
          and margin.


    The height of the window content rect is the minimum of:
      = the height of the content rect of a window filling the screen
      = the maximum of:
        = a minimum height of 161.
	= the sum of:
          = The height of the icon, the line and their interspaces.
          = The height of the messageField and its interspaces, if present.
          = The height of the buttons and their interspaces, if present.


    The size of the scroll view must be at minimum ScrollMinSize
    in each direction.

    The size of the messageField is a given (sizeToFit).

    The height of the scroll is the rest of the height of the content rect
    minus the height of the other elements.

    The width of the scroll is the rest of the width of the content rect
    minus the margins.

    ((wsize.width <= ssize.width)
     and ([messageField frame].size.width+2*MessageHorzMargin <= wsize.width))
    or ((wsize.width == ssize.width)
        and ([scroll frame].size.width = wsize.width-2*MessageHorzMargin));

    ...
*/


@class	GSAlertPanel;

static GSAlertPanel	*standardAlertPanel = nil;
static GSAlertPanel	*informationalAlertPanel = nil;
static GSAlertPanel	*criticalAlertPanel = nil;

@interface	GSAlertPanel: NSPanel
{
  NSButton	*defButton;
  NSButton	*altButton;
  NSButton	*othButton;
  NSButton	*icoButton;
  NSTextField	*titleField;
  NSTextField	*messageField;
  NSScrollView	*scroll;
  int		result;
  BOOL          isGreen;  // we were unarchived and not resized.
}

- (id) _initWithoutGModel;
- (int) runModal;
- (void) setTitle: (NSString*)title
	  message: (NSString*)message
	      def: (NSString*)defaultButton
	      alt: (NSString*)alternateButton
	    other: (NSString*)otherButton;
- (void) sizePanelToFit;
- (void) buttonAction: (id)sender;
- (int) result;
- (BOOL) isActivePanel;
@end


@implementation	GSAlertPanel

//static const float WTitleHeight = 0.0;      // TODO: Check this value.
static const float WinMinWidth = 362.0;
static const float WinMinHeight = 161.0;
static const float IconSide = 48.0;
static const float IconBottom = -56.0;       // from the top of the window.
static const float IconLeft = 8.0;
static const float TitleLeft = 64.0;
static const float TitleMinRight = 8.0;
static const float LineHeight = 2.0;
static const float LineBottom = -66.0;       // from the top of the window.
static const float LineLeft = 0.0;
//static const float ScrollMinSize = 48.0;     // in either direction.
static const float MessageHorzMargin = 8.0;  // 5 is too little margin.
//static const float MessageMinHeight = 20.0;
static const float MessageVertMargin = 6.0;  // from the top of the buttons.
static const float MessageTop = -72;         // from the top of the window;
static const float ButtonBottom = 8.0;       // from the bottom of the window.
static const float ButtonMargin = 8.0;
static const float ButtonInterspace = 10.0;
static const float ButtonMinHeight = 24.0;
static const float ButtonMinWidth = 72.0;

#define MessageFont [NSFont messageFontOfSize: 14]

+ (void) initialize
{
  if (self == [GSAlertPanel class])
    {
      [self setVersion: 1];
    }
}

- (id) init
{
/*
  if (![NSBundle loadNibNamed: @"AlertPanel" owner: self])
    {
      NSLog(@"cannot open alert panel model file\n");
      return nil;
    }
 */
  return [self _initWithoutGModel];
}

- (void) dealloc
{
  if (self == standardAlertPanel)
    {
      standardAlertPanel = nil;
    }
  if (self == informationalAlertPanel)
    {
      informationalAlertPanel = nil;
    }
  if (self == criticalAlertPanel)
    {
      criticalAlertPanel = nil;
    }
  RELEASE(defButton);
  RELEASE(altButton);
  RELEASE(othButton);
  RELEASE(icoButton);
  RELEASE(titleField);
  RELEASE(messageField);
  RELEASE(scroll);
  [super dealloc];
}

static NSScrollView*
makeScrollViewWithRect(NSRect rect)
{
  float		lineHeight = [MessageFont boundingRectForFont].size.height;
  NSScrollView	*scroll = [[NSScrollView alloc]initWithFrame: rect];

  [scroll setBorderType: NSLineBorder];
  [scroll setBackgroundColor: [NSColor controlBackgroundColor]];
  [scroll setHasHorizontalScroller: YES];
  [scroll setHasVerticalScroller: YES];
  [scroll setScrollsDynamically: YES];
  [scroll setLineScroll: lineHeight];
  [scroll setPageScroll: lineHeight*10.0];
  return scroll;
}

- (NSButton*) _makeButtonWithRect: (NSRect)rect
{
  NSButton	*button = [[NSButton alloc] initWithFrame: rect];

  [button setAutoresizingMask: NSViewMinXMargin | NSViewMaxYMargin];
  [button setButtonType: NSMomentaryPushButton];
  [button setTitle: @""];
  [button setTarget: self];
  [button setAction: @selector(buttonAction: )];
  [button setFont: [NSFont systemFontOfSize: 0]];
  return button;
}

#define useControl(control)  ([control superview] != nil)

static void
setControl(NSView* content, id control, NSString *title)
{
  if (title != nil)
    {
      if ([control respondsToSelector: @selector(setTitle:)])
	{
	  [control setTitle: title];
	}
      else if ([control respondsToSelector: @selector(setStringValue:)])
	{
	  [control setStringValue: title];
	}
      [control sizeToFit];
      if (!useControl(control))
	{
	  [content addSubview: control];
	}
    }
  else if (useControl(control))
    {
      [control removeFromSuperview];
    }
}

- (id) _initWithoutGModel
{
  NSRect  rect;
  NSImage *image;
  NSBox	  *box;
  NSView  *content;
  NSRect  r = NSMakeRect(0.0, 0.0, WinMinWidth, WinMinHeight);
  NSFont  *titleFont = [NSFont systemFontOfSize: 18.0];
  float   titleHeight = [titleFont boundingRectForFont].size.height;


  self = [self initWithContentRect: r
	       styleMask: NSTitledWindowMask
	       backing: NSBackingStoreRetained
	       defer: YES
	       screen: nil];

  if (self == nil)
    return nil;

  [self setTitle: @" "];
  content = [self contentView];
  
  // we're an ATTENTION panel, therefore:
  [self setHidesOnDeactivate: NO];
  [self setBecomesKeyOnlyIfNeeded: NO];
  
  // First, the subviews that will be positioned automatically.
  rect.size.height = IconSide;
  rect.size.width = IconSide;
  rect.origin.y = r.origin.y + r.size.height + IconBottom;
  rect.origin.x = IconLeft;
  icoButton = [[NSButton alloc] initWithFrame: rect];
  [icoButton setAutoresizingMask: NSViewMaxXMargin|NSViewMinYMargin];
  [icoButton setBordered: NO];
  [icoButton setEnabled: NO];
  [icoButton setImagePosition: NSImageOnly];
  image = [[NSApplication sharedApplication] applicationIconImage];
  [icoButton setImage: image];
  [content addSubview: icoButton];

  // Title
  rect.size.height = 0.0; // will be sized to fit anyway.
  rect.size.width = 0.0;  // will be sized to fit anyway.
  rect.origin.y = r.origin.y + r.size.height 
                  + IconBottom + (IconSide - titleHeight)/2;;
  rect.origin.x = TitleLeft;
  titleField = [[NSTextField alloc] initWithFrame: rect];
  [titleField setAutoresizingMask: NSViewMinYMargin];
  [titleField setEditable: NO];
  [titleField setSelectable: YES];
  [titleField setBezeled: NO];
  [titleField setDrawsBackground: NO];
  [titleField setStringValue: @""];
  [titleField setFont: titleFont];

  // Horizontal line
  rect.size.height = LineHeight;
  rect.size.width = r.size.width;
  rect.origin.y = r.origin.y + r.size.height + LineBottom;
  rect.origin.x = LineLeft;
  box = [[NSBox alloc] initWithFrame: rect];
  [box setAutoresizingMask: NSViewWidthSizable | NSViewMinYMargin];
  [box setTitlePosition: NSNoTitle];
  [box setBorderType: NSGrooveBorder];
  [content addSubview: box];
  RELEASE(box);
  
  // Then, make the subviews that'll be sized by sizePanelToFit;
  rect.size.height = 0.0;
  rect.size.width = 0.0;
  rect.origin.y = 0.0;
  rect.origin.x = 0.0;
  
  messageField = [[NSTextField alloc] initWithFrame: rect];
  [messageField setEditable: NO];
  [messageField setSelectable: YES];
  /*
    PJB:
    How do you  want the user to report an error  message if it is
    not selectable?  Any text visible on the  screen should always
    be selectable for a copy-and-paste. Hence, setSelectable: YES.
  */
  [messageField setBezeled: NO];
  [messageField setDrawsBackground: YES];
  [messageField setBackgroundColor: [NSColor controlBackgroundColor]];
  [messageField setAlignment: NSCenterTextAlignment];
  [messageField setStringValue: @""];
  [messageField setFont: MessageFont];
  
  defButton = [self _makeButtonWithRect: rect];
  [defButton setKeyEquivalent: @"\r"];
  [defButton setHighlightsBy: NSPushInCellMask | NSChangeGrayCellMask 
                              | NSContentsCellMask];
  [defButton setImagePosition: NSImageRight];
  [defButton setImage: [NSImage imageNamed: @"common_ret"]];
  [defButton setAlternateImage: [NSImage imageNamed: @"common_retH"]];
  
  altButton = [self _makeButtonWithRect: rect];
  othButton = [self _makeButtonWithRect: rect];
  
  rect.size.height = 80.0;
  scroll = makeScrollViewWithRect(rect);
  
  result = NSAlertErrorReturn;
  isGreen = YES;

  return self;
}

- (void) sizePanelToFit
{
  NSRect	bounds;
  NSSize	ssize; 			// screen size (corrected).
  NSSize	bsize; 			// button size (max of the three).
  NSSize	wsize = {0.0, 0.0}; 	// window size (computed).
  NSScreen	*screen;
  NSView	*content;
  NSButton	*buttons[3];
  float		position = 0.0;
  int		numberOfButtons;
  int		i;
  BOOL		needsScroll;
  BOOL		couldNeedScroll;
  unsigned int	mask = [self styleMask];

  /*
   * Set size to the size of a content rectangle of a panel
   * that completely fills the screen.
   */
  screen = [self screen];
  if (screen == nil)
    {
      screen = [NSScreen mainScreen];
    }
  bounds = [screen frame];
  bounds = [NSWindow contentRectForFrameRect: bounds styleMask: mask];
  ssize = bounds.size;

  // Let's size the title.
  if (useControl(titleField))
    {
      NSRect	rect = [titleField frame];
      float	width = TitleLeft + rect.size.width + TitleMinRight;

      if (wsize.width < width)
	{
	  wsize.width = width;
	  // ssize.width < width = > the title will be silently clipped.
	}
    }

  wsize.height = -LineBottom;


  // Let's count the buttons.
  bsize.width = ButtonMinWidth;
  bsize.height = ButtonMinHeight;
  buttons[0] = defButton;
  buttons[1] = altButton;
  buttons[2] = othButton;
  numberOfButtons = 0;
  for (i = 0; i < 3; i++)
    {
      if (useControl(buttons[i]))
	{
	  NSRect rect = [buttons[i] frame];

	  if (bsize.width < rect.size.width)
	    {
	      bsize.width = rect.size.width;
	    }
	  if (bsize.height < rect.size.height)
	    {
	      bsize.height = rect.size.height;
	    }
	  numberOfButtons++;
	}
    }

  if (numberOfButtons > 0)
    {
      // (with NSGetAlertPanel, there could be zero buttons).
      float	width = (bsize.width + ButtonInterspace) * numberOfButtons
		  -ButtonInterspace + ButtonMargin * 2;
      /*
       * If the buttons are too wide or too high to fit in the screen,
       * then too bad! Thought it would be simple enough to put them
       * in the scroll view with the messageField.
       * TODO: See if we raise an exception here or if we let the
       *       QA people detect this kind of problem.
       */
      if (wsize.width < width)
	{
	  wsize.width = width;
	}
      wsize.height += ButtonBottom + bsize.height;
    }

  // Let's see the size of the messageField and how to place it.
  needsScroll = NO;
  couldNeedScroll = useControl(messageField);
  if (couldNeedScroll)
    {
      NSRect	rect = [messageField frame];
      float	width = rect.size.width + 2*MessageHorzMargin;

      if (wsize.width < width)
	{
	  wsize.width = width;
	}
      // The title could be large too, without implying a scroll view.
      needsScroll = (ssize.width < width);
      /*
       * But only the messageField can impose a great height, therefore
       * we check it along in the next paragraph.
       */
      wsize.height += rect.size.height + 2 * MessageVertMargin;
    }
  else
    {
      wsize.height += MessageVertMargin;
    }

  // Strategically placed here, we resize the window.
  if (ssize.height < wsize.height)
    {
      wsize.height = ssize.height;
      needsScroll = couldNeedScroll;
    }
  else if (wsize.height < WinMinHeight)
    {
      wsize.height = WinMinHeight;
    }
  if (needsScroll)
    {
      wsize.width += [NSScroller scrollerWidth] + 4.0;
    }
  if (ssize.width < wsize.width)
    {
      wsize.width = ssize.width;
    }
  else if (wsize.width < WinMinWidth)
    {
      wsize.width = WinMinWidth;
    }
  bounds = NSMakeRect(0, 0, wsize.width, wsize.height);
  bounds = [NSWindow frameRectForContentRect: bounds styleMask: mask];
  [self setMaxSize: bounds.size];
  [self setMinSize: bounds.size];
  [self setContentSize: wsize];
  content = [self contentView];
  bounds = [content bounds];

  // Now we can place the buttons.
  if (numberOfButtons > 0)
    {
      position = bounds.origin.x + bounds.size.width - ButtonMargin;
      for (i = 0; i < 3; i++)
	{
	  if (useControl(buttons[i]))
	    {
	      NSRect	rect;

	      position -= bsize.width;
	      rect.origin.x = position;
	      rect.origin.y = bounds.origin.y + ButtonBottom;
	      rect.size.width = bsize.width;
	      rect.size.height = bsize.height;
	      [buttons[i] setFrame: rect];
	      position -= ButtonInterspace;
	    }
	}
    }

  // Finaly, place the message.
  if (useControl(messageField))
    {
      NSRect	mrect = [messageField frame];

      if (needsScroll)
	{
	  NSRect	srect;

	  // The scroll view takes all the space that is available.
	  srect.origin.x = bounds.origin.x + MessageHorzMargin;
	  if (numberOfButtons > 0)
	    {
	      srect.origin.y = bounds.origin.y + ButtonBottom
		+ bsize.height + MessageVertMargin;
	    }
	  else
	    {
	      srect.origin.y = bounds.origin.y + MessageVertMargin;
	    }
	  srect.size.width = bounds.size.width - 2 * MessageHorzMargin;
	  srect.size.height = bounds.origin.y + bounds.size.height
	    + MessageTop - srect.origin.y;
	  [scroll setFrame: srect];
	  if (!useControl(scroll))
	    {
	      [content addSubview: scroll];
	    }
	  [messageField removeFromSuperview];
	  mrect.origin.x
	    = srect.origin.x + srect.size.width - mrect.size.width;
	  mrect.origin.y
	    = srect.origin.y + srect.size.height - mrect.size.height;
	  [messageField setFrame: mrect];
	  [scroll setDocumentView: messageField];
	  [[scroll contentView]scrollToPoint:
	    NSMakePoint(mrect.origin.x, mrect.origin.y + mrect.size.height
	      -[[scroll contentView] bounds].size.height)];
	  [scroll reflectScrolledClipView: [scroll contentView]];
	}
      else
	{
	  float	vmargin;

	  /*
	   * We must center vertically the messageField because
	   * the window has a minimum size, thus may be greated
	   * than expected.
	   */
	  mrect.origin.x = (wsize.width - mrect.size.width)/2;
	  vmargin = bounds.size.height + LineBottom-mrect.size.height;
	  if (numberOfButtons > 0)
	    {
	      vmargin -= ButtonBottom + bsize.height;
	    }
	  vmargin/= 2.0; // if negative, it'll bite up and down.
	  mrect.origin.y = bounds.origin.y + vmargin;
	  if (numberOfButtons > 0)
	    {
	      mrect.origin.y += ButtonBottom + bsize.height;
	    }
	  [messageField setFrame: mrect];
	}
    }
  else if (useControl(scroll))
    {
      [scroll removeFromSuperview];
    }

  isGreen = NO;
  [content display];
}

- (void) buttonAction: (id)sender
{
  if (![self isActivePanel])
    {
      NSLog(@"alert panel buttonAction: when not in modal loop\n");
      return;
    }
  else if (sender == defButton)
    {
      result = NSAlertDefaultReturn;
    }
  else if (sender == altButton)
    {
      result = NSAlertAlternateReturn;
    }
  else if (sender == othButton)
    {
      result = NSAlertOtherReturn;
    }
  else
    {
      NSLog(@"alert panel buttonAction: from unknown sender - x%x\n",
	(unsigned)sender);
    }
  [NSApp stopModalWithCode: result];
}

- (int) result
{
  return result;
}

- (BOOL) isActivePanel
{
  return [NSApp modalWindow] == self;
}

- (int) runModal
{
  if (isGreen)
    {
      [self sizePanelToFit];
    }

  [NSApp runModalForWindow: self];
  [self orderOut: self];
  return result;
}

- (void) setTitle: (NSString*)title
	  message: (NSString*)message
	      def: (NSString*)defaultButton
	      alt: (NSString*)alternateButton
	    other: (NSString*)otherButton
{
  NSView	*content = [self contentView];

  setControl(content, titleField, title);
  if (useControl(scroll))
    { 
      // TODO: Remove the following line once NSView is corrected.
      [scroll setDocumentView: nil];
      [scroll removeFromSuperview];
      [messageField removeFromSuperview];
    }
  setControl(content, messageField, message);
  setControl(content, defButton, defaultButton);
  setControl(content, altButton, alternateButton);
  setControl(content, othButton, otherButton);
  if (useControl(defButton))
    {
      [self makeFirstResponder: defButton];
    }
  else
    {
      [self makeFirstResponder: self];
    }

  /* a *working* nextKeyView chain:
     the trick is that the 3 buttons are not always used (displayed)
     so we have to set the nextKeyView *each* time.
     Maybe some optimisation in the logic of this block will be good,
     however it seems too risky for a (so) small reward
     */
  {
    BOOL ud, ua, uo;
    ud = useControl(defButton);
    ua = useControl(altButton);
    uo = useControl(othButton);
    
    if (ud)
      {
	if (uo)
	  [defButton setNextKeyView: othButton];
	else if (ua)
	  [defButton setNextKeyView: altButton];
	else
	  {
	    [defButton setPreviousKeyView:nil];
	    [defButton setNextKeyView: nil];
	  }
      }
    
    if (uo)
      {
	if (ua)
	  [othButton setNextKeyView: altButton];
	else if (ud)
	  [othButton setNextKeyView: defButton];
	else
	  {
	    [othButton setPreviousKeyView:nil];
	    [othButton setNextKeyView: nil];
	  }
      }

    if (ua)
      {
	if (ud)
	  [altButton setNextKeyView: defButton];
	else if (uo)
	  [altButton setNextKeyView: othButton];
	else
	  {
	    [altButton setPreviousKeyView:nil];
	    [altButton setNextKeyView: nil];
	  }
      }
  }

  isGreen = YES;
  result = NSAlertErrorReturn; 	/* If no button was pressed	*/
}

@end /* GSAlertPanel */

@implementation GSAlertPanel (GMArchiverMethods)

// Reuse createObjectForModelUnarchiver: from super class

- (void) encodeWithModelArchiver: (GMArchiver*)archiver
{
  [super encodeWithModelArchiver: archiver];
  [archiver encodeSize: [self frame].size withName: @"OriginalSize"];
  [archiver encodeObject: defButton withName: @"DefaultButton"];
  [archiver encodeObject: altButton withName: @"AlternateButton"];
  [archiver encodeObject: othButton withName: @"OtherButton"];
  [archiver encodeObject: icoButton withName: @"IconButton"];
  [archiver encodeObject: messageField withName: @"MessageField"];
  [archiver encodeObject: titleField withName: @"TitleField"];
}

- (id) initWithModelUnarchiver: (GMUnarchiver*)unarchiver
{
  self = [super initWithModelUnarchiver: unarchiver];
  if (self != nil)
    {
      (void)[unarchiver decodeSizeWithName: @"OriginalSize"];
      defButton = RETAIN([unarchiver decodeObjectWithName: @"DefaultButton"]);
      altButton = RETAIN([unarchiver decodeObjectWithName: @"AlternateButton"]);
      othButton = RETAIN([unarchiver decodeObjectWithName: @"OtherButton"]);
      icoButton = RETAIN([unarchiver decodeObjectWithName: @"IconButton"]);
      messageField = RETAIN([unarchiver decodeObjectWithName: @"MessageField"]);
      titleField = RETAIN([unarchiver decodeObjectWithName: @"TitleField"]);
      scroll = makeScrollViewWithRect(NSMakeRect(0.0, 0.0, 80.0, 80.0));
      result = NSAlertErrorReturn;
      isGreen = YES;
    }
  return self;
}

@end /* GSAlertPanel GMArchiverMethods */

/*
  These functions may be called "recursively". For example, from a
  timed event. Therefore, there  may be several alert panel active
  at  the  same  time,  but   only  the  first  one  will  be  THE
  standardAlertPanel,  which will  not be  released  once finished
  with, but which will be kept for future use.

	   +---------+---------+---------+---------+---------+
	   | std !=0 | std act | pan=std | pan=new | std=new |
	   +---------+---------+---------+---------+---------+
     a:    |    F    |   N/A   |         |    X    |    X    |
	   +---------+---------+---------+---------+---------+
     b:    |    V    |    F    |    X    |         |         |
	   +---------+---------+---------+---------+---------+
     c:    |    V    |    V    |         |    X    |         |
	   +---------+---------+---------+---------+---------+
*/


/*
    TODO: Check if this discrepancy is wanted and needed.
          If not, we could merge these parameters, even
          for the alert panel, setting its window title to "Alert".
*/

static GSAlertPanel*
getSomePanel(
  GSAlertPanel **instance,
  NSString *defaultTitle,
  NSString *title,
  NSString *message,
  NSString *defaultButton,
  NSString *alternateButton,
  NSString *otherButton)
{
  GSAlertPanel	*panel;

  if (*instance != 0)
    {
      if ([*instance isActivePanel])
	{				// c:
	  panel = [[GSAlertPanel alloc] init];
	}
      else
	{				// b:
	  panel = *instance;
	}
    }
  else
    { 					// a:
      panel = [[GSAlertPanel alloc] init];
      *instance = panel;
    }

  if (title == nil)
    {
      title = defaultTitle;
    }

  if (defaultTitle != nil)
    {
      [panel setTitle: defaultTitle];
    }
  [panel setTitle: title
	  message: message
	      def: defaultButton
	      alt: alternateButton
	    other: otherButton];
  [panel sizePanelToFit];
  return panel;
}

id
NSGetAlertPanel(
  NSString *title,
  NSString *msg,
  NSString *defaultButton,
  NSString *alternateButton,
  NSString *otherButton, ...)
{
  va_list	ap;
  NSString	*message;

  va_start(ap, otherButton);
  message = [NSString stringWithFormat: msg arguments: ap];
  va_end(ap);

  return getSomePanel(&standardAlertPanel, defaultTitle, title, message,
    defaultButton, alternateButton, otherButton);
}

int
NSRunAlertPanel(
  NSString *title,
  NSString *msg,
  NSString *defaultButton,
  NSString *alternateButton,
  NSString *otherButton, ...)
{
  va_list	ap;
  NSString	*message;
  GSAlertPanel	*panel;
  int		result;

  va_start(ap, otherButton);
  message = [NSString stringWithFormat: msg arguments: ap];
  va_end(ap);

  if (defaultButton == nil)
    {
      defaultButton = @"OK";
    }

  panel = getSomePanel(&standardAlertPanel, defaultTitle, title, message,
    defaultButton, alternateButton, otherButton);
  result = [panel runModal];
  NSReleaseAlertPanel(panel);
  return result;
}

int
NSRunLocalizedAlertPanel(
  NSString *table,
  NSString *title,
  NSString *msg,
  NSString *defaultButton,
  NSString *alternateButton,
  NSString *otherButton, ...)
{
  va_list	ap;
  NSString	*message;
  GSAlertPanel	*panel;
  int		result;
  NSBundle	*bundle = [NSBundle mainBundle];

  if (title == nil)
    {
      title = defaultTitle;
    }

#define localize(string) if (string != nil) \
  string = [bundle localizedStringForKey: string value: string table: table]

  localize(title);
  localize(defaultButton);
  localize(alternateButton);
  localize(otherButton);
  localize(msg);

#undef localize

  va_start(ap, otherButton);
  message = [NSString stringWithFormat: msg arguments: ap];
  va_end(ap);

  if (defaultButton == nil)
    {
      defaultButton = @"OK";
    }

  panel = getSomePanel(&standardAlertPanel, @"Alert", title, message,
		     defaultButton, alternateButton, otherButton);
  result = [panel runModal];
  NSReleaseAlertPanel(panel);
  return result;
}



id
NSGetCriticalAlertPanel(
  NSString *title,
  NSString *msg,
  NSString *defaultButton,
  NSString *alternateButton,
  NSString *otherButton, ...)
{
  va_list	ap;
  NSString	*message;

  va_start(ap, otherButton);
  message = [NSString stringWithFormat: msg arguments: ap];
  va_end(ap);

  return getSomePanel(&criticalAlertPanel, @"Critical", title, message,
    defaultButton, alternateButton, otherButton);
}


int
NSRunCriticalAlertPanel(
  NSString *title,
  NSString *msg,
  NSString *defaultButton,
  NSString *alternateButton,
  NSString *otherButton, ...)
{
  va_list	ap;
  NSString	*message;
  GSAlertPanel	*panel;
  int		result;

  va_start(ap, otherButton);
  message = [NSString stringWithFormat: msg arguments: ap];
  va_end(ap);

  panel = getSomePanel(&criticalAlertPanel, @"Critical", title, message,
    defaultButton, alternateButton, otherButton);
  result = [panel runModal];
  NSReleaseAlertPanel(panel);
  return result;
}


id
NSGetInformationalAlertPanel(
  NSString *title,
  NSString *msg,
  NSString *defaultButton,
  NSString *alternateButton,
  NSString *otherButton, ...)
{
  va_list	ap;
  NSString	*message;

  va_start(ap, otherButton);
  message = [NSString stringWithFormat: msg arguments: ap];
  va_end(ap);

  return getSomePanel(&informationalAlertPanel, @"Information", title, message,
    defaultButton, alternateButton, otherButton);
}


int
NSRunInformationalAlertPanel(
  NSString *title,
  NSString *msg,
  NSString *defaultButton,
  NSString *alternateButton,
  NSString *otherButton, ...)
{
  va_list       ap;
  NSString	*message;
  GSAlertPanel	*panel;
  int		result;

  va_start(ap, otherButton);
  message = [NSString stringWithFormat: msg arguments: ap];
  va_end(ap);

  panel = getSomePanel(&informationalAlertPanel,
		      @"Information",
		      title, message,
		      defaultButton, alternateButton, otherButton);
  result = [panel runModal];
  NSReleaseAlertPanel(panel);
  return result;
}


void
NSReleaseAlertPanel(id panel)
{
  if ((panel != standardAlertPanel)
     && (panel != informationalAlertPanel)
     && (panel != criticalAlertPanel))
    {
      RELEASE(panel);
    }
}

//
// New alert interface of Mac OS X
//
void NSBeginAlertSheet(NSString *title, 
		       NSString *defaultButton, 
		       NSString *alternateButton, 
		       NSString *otherButton, 
		       NSWindow *docWindow, 
		       id modalDelegate, 
		       SEL willEndSelector, 
		       SEL didEndSelector, 
		       void *contextInfo, 
		       NSString *msg, ...)
{
  va_list	ap;
  NSString	*message;
  GSAlertPanel	*panel;

  va_start(ap, msg);
  message = [NSString stringWithFormat: msg arguments: ap];
  va_end(ap);

  if (defaultButton == nil)
    {
      defaultButton = @"OK";
    }

  panel = getSomePanel(&standardAlertPanel, defaultTitle, title, message,
    defaultButton, alternateButton, otherButton);
  
  // FIXME: We should also change the button action to call endSheet:
  [NSApp beginSheet: panel
	 modalForWindow: docWindow
	 modalDelegate: modalDelegate
	 didEndSelector: didEndSelector
	 contextInfo: contextInfo];
  [panel close];
  NSReleaseAlertPanel(panel);
}

void NSBeginCriticalAlertSheet(NSString *title, 
			       NSString *defaultButton, 
			       NSString *alternateButton, 
			       NSString *otherButton, 
			       NSWindow *docWindow, 
			       id modalDelegate, 
			       SEL willEndSelector, 
			       SEL didEndSelector, 
			       void *contextInfo, 
			       NSString *msg, ...)
{
  va_list	ap;
  NSString	*message;
  GSAlertPanel	*panel;

  va_start(ap, msg);
  message = [NSString stringWithFormat: msg arguments: ap];
  va_end(ap);

  panel = getSomePanel(&criticalAlertPanel, @"Critical", title, message,
    defaultButton, alternateButton, otherButton);

  // FIXME: We should also change the button action to call endSheet:
  [NSApp beginSheet: panel
	 modalForWindow: docWindow
	 modalDelegate: modalDelegate
	 didEndSelector: didEndSelector
	 contextInfo: contextInfo];
  [panel close];
  NSReleaseAlertPanel(panel);
}

void NSBeginInformationalAlertSheet(NSString *title, 
				    NSString *defaultButton, 
				    NSString *alternateButton, 
				    NSString *otherButton,
				    NSWindow *docWindow, 
				    id modalDelegate, 
				    SEL willEndSelector, 
				    SEL didEndSelector, 
				    void *contextInfo, 
				    NSString *msg, ...)
{
  va_list       ap;
  NSString	*message;
  GSAlertPanel	*panel;

  va_start(ap, msg);
  message = [NSString stringWithFormat: msg arguments: ap];
  va_end(ap);

  panel = getSomePanel(&informationalAlertPanel,
		      @"Information",
		      title, message,
		      defaultButton, alternateButton, otherButton);

  // FIXME: We should also change the button action to call endSheet:
  [NSApp beginSheet: panel
	 modalForWindow: docWindow
	 modalDelegate: modalDelegate
	 didEndSelector: didEndSelector
	 contextInfo: contextInfo];
  [panel close];
  NSReleaseAlertPanel(panel);
}


@implementation	NSAlert

/*
 * Class methods
 */
+ (void)initialize
{
  if (self  ==  [NSAlert class])
    {
      [self setVersion: 1];
    }
}

+ (NSAlert *)alertWithMessageText:(NSString *)messageTitle
		    defaultButton:(NSString *)defaultButtonTitle
		  alternateButton:(NSString *)alternateButtonTitle
		      otherButton:(NSString *)otherButtonTitle
	informativeTextWithFormat:(NSString *)format, ...
{
  va_list ap;
  NSAlert *alert = [[self alloc] init];
  NSString *text;

  va_start(ap, format);
  if (format != nil)
    {
      text = [[NSString alloc] initWithFormat: format arguments: ap];
      [alert setInformativeText: text];
      RELEASE(text);
    }
  va_end(ap);

  [alert setMessageText: messageTitle];

  if (defaultButtonTitle != nil)
    {
	[alert addButtonWithTitle: defaultButtonTitle];
    }
  else
    {
	[alert addButtonWithTitle: _(@"OK")];
    }

  if (alternateButtonTitle != nil)
    {
	[alert addButtonWithTitle: alternateButtonTitle];
    }

  if (otherButtonTitle != nil)
    {
	[alert addButtonWithTitle: otherButtonTitle];
    }

  return AUTORELEASE(alert);
}

- (id) init
{
  _buttons = [[NSMutableArray alloc] init];
  _style = NSWarningAlertStyle;
  return self;
} 

- (void) dealloc
{
  RELEASE(_informative_text);
  RELEASE(_message_text);
  RELEASE(_icon);
  RELEASE(_buttons);
  RELEASE(_help_anchor);
  RELEASE(_window);
  [super dealloc];
}

- (void)setInformativeText:(NSString *)informativeText
{
  ASSIGN(_informative_text, informativeText);
}

- (NSString *)informativeText
{
  return _informative_text;
}

- (void)setMessageText:(NSString *)messageText
{
  ASSIGN(_message_text, messageText);
}

- (NSString *)messageText
{
  return _message_text;
}

- (void)setIcon:(NSImage *)icon
{
  ASSIGN(_icon, icon);
}

- (NSImage *)icon
{
  return _icon;
}

- (NSButton *)addButtonWithTitle:(NSString *)aTitle
{
  NSButton *button = [[NSButton alloc] init];
  int count = [_buttons count];

  [button setTitle: aTitle];
  [button setAutoresizingMask: NSViewMinXMargin | NSViewMaxYMargin];
  [button setButtonType: NSMomentaryPushButton];
  [button setTarget: self];
  [button setAction: @selector(buttonAction: )];
  [button setFont: [NSFont systemFontOfSize: 0]];
  if (count == 0)
    {
      [button setTag: NSAlertFirstButtonReturn];
      [button setKeyEquivalent: @"\r"];
    }
  else
    {
      [button setTag: NSAlertFirstButtonReturn + count];
      if ([aTitle isEqualToString: @"Cancel"])
        {
	  [button setKeyEquivalent: @"\e"];
	}
      else if ([aTitle isEqualToString: @"Don't Save"])
        {
	  [button setKeyEquivalent: @"D"];
	  [button setKeyEquivalentModifierMask: NSCommandKeyMask];
	}
    }

  [_buttons addObject: button];
  RELEASE(button);
  return button;
}

- (NSArray *)buttons
{
  return _buttons;
}

- (void)setShowsHelp:(BOOL)showsHelp
{
  _shows_help = showsHelp;
}

- (BOOL)showsHelp
{
  return _shows_help;
}

- (void)setHelpAnchor:(NSString *)anchor
{
  ASSIGN(_help_anchor, anchor);
}

- (NSString *)helpAnchor
{
  return _help_anchor;
}

- (void)setAlertStyle:(NSAlertStyle)style
{
  _style = style;
}

- (NSAlertStyle)alertStyle
{
  return _style;
}

- (void)setDelegate:(id)delegate
{
  _delegate = delegate;
}

- (id)delegate
{
  return _delegate;
}

- (int)runModal
{
  // FIXME
  return NSAlertFirstButtonReturn;
}

- (void)beginSheetModalForWindow:(NSWindow *)window
		   modalDelegate:(id)delegate
		  didEndSelector:(SEL)didEndSelector
		     contextInfo:(void *)contextInfo
{
// FIXME
}

- (id)window
{
  return _window;
}

@end