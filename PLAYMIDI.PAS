{ Initially written in 1996, Small bug Correction in 2020 }

Program Play;
Uses CRT,GMUnit,VarMidi,ChMidi,PlMidi;

Const 

 {FileName:String='C:\MIDI\DUNE2\01.MID';}
 FileName:String='C:\MIDI\DOOM\01.MID';
 {FileName:String='C:\MIDI\DESCENT\TRACK01.MID';}

Var Erreur:Word;

Begin
Clrscr;
Writeln('PlayMIDI (c) 1996 Freddy vetele ');
Writeln('File Path Hardcoded in the code');
Writeln(FileName);
Writeln;

If GMDetecte Then GMActive;

Charge_Midi(FileName,Erreur);

If Erreur=0 Then
   Begin
    Writeln('Format :',MIDI.Format);
	Writeln('Pistes :',MIDI.NbPistes);
	Writeln('Division :',MIDI.Division);
	
   Writeln('Playing... (Esc to Quit)');
   Writeln;
   MStart;
   Jouer_Midi;
   MStop;
   Writeln;
   Writeln('Fin... :-(');
   End
   Else Writeln('Erreur de chargement');
End.