# AngleFun (lid piano)

A small macOS musical experiment that turns a MacBook into a motion-controlled
synthesizer. Play notes from the keyboard or click the on-screen piano, then
move the laptop lid to change the sound while notes are playing.

The project reads the current lid angle and uses it as a musical control:
opening and closing the screen changes the pitch and brightness of the synth.
It is a simple way to make a familiar physical movement feel like part of an
instrument.

[![image.png](https://i.postimg.cc/BbnG7ZHf/image.png)](https://postimg.cc/2bMJVD00)
<sub>The lid angle and playable keyboard shown in the macOS app.</sub>

## Features

- Plays white piano keys with `A S D F G H J K L ;`
- Plays black piano keys with `W E T Y U O P`
- Works with the same physical keyboard keys in English and Russian layouts
- Supports mouse interaction with both white and black on-screen keys
- Allows multiple notes to be held at once
- Changes pitch and tone continuously according to the MacBook lid angle
- Highlights pressed notes in the on-screen keyboard

## Controls

Press and hold a keyboard key or an on-screen piano key to play a note. While
the note is sounding, slowly change the lid angle to hear the synth respond.

The app is intended for a MacBook with an available lid angle HID sensor.

## Technologies

- `Swift` and `SwiftUI` for the macOS app interface
- `AppKit` for physical keyboard input handling
- `AVFoundation` / `AVAudioEngine` for real-time sound synthesis
- `IOKit HID` for reading the MacBook lid angle sensor
