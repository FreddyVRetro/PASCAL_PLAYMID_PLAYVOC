{--------------------------------------------------------------------}
{                        -== PlayVoc V1.0 ==-                        }
{                                                                    }
{                                                                    }
{                                            (c) 1994 Freddy V‚tel‚  }
{--------------------------------------------------------------------}

Program Playvoc;

Uses Crt,Dos;

Const

  CLI=$FA;
  STI=$FB;

  IRQ_SB=7;               { IRQ entre 0 et 7 }
  DMA_SB=1;               { DMA 0,1 ou 3     }
  Port_de_base=$220;
  Port_init=Port_de_base+$06;
  Port_lecture=Port_de_base+$0A;
  Port_instructions=Port_de_base+$0C;
  Port_etat=Port_de_base+$0E;
  Page_DMA:Array[0..3] of Word=($87,$83,$81,$82);


Type
 T_en_tete_voc=Record
               Identificateur:Array[1..19] of char;
               Octet_EOF:Byte;
               Mot_reserve:Word;
               Version_decimal:Byte;
               Version_entier:Byte;
               Code_identification:Word;
               End;

 T_en_tete_bloc=Record
               Type_bloc:Byte;
               Taille_l:Byte;
               Taille_h:Word;
               End;

Var
    Sample      :Pointer;
    En_tete_voc :T_en_tete_voc;
    En_tete_bloc:T_en_tete_bloc;
    Frequence_SB:Byte;
    Compression :Byte;

    Nom_fichier:String;
    Erreur:Byte;
    Taille:Longint;
    Sauvegarde_Port_controleur:Byte;
    vecteur_initial:pointer;
    Fin_du_sample:Boolean;

{--------------------------------------------------------------------}

Procedure Attendre_SB;
Var i,donnee:byte;

Begin
While (donnee<128) and (i<100) do
      Begin
      Donnee:=Port[Port_instructions];
      Inc(i);
      End;

End;  { Attendre_SB }

{--------------------------------------------------------------------}

Function InitSB : Boolean;   { Initialise et d‚tecte la sound blaster }

Var
    i,donnee : BYTE;

Begin

Port[Port_init]:=1;
For i:=1 to 100 do Port[Port_init] := 0;

donnee:= 0;
i:=0;
While (donnee<>$AA) and (i<100) do
      Begin
      donnee:=Port[Port_etat];
      donnee:=Port[Port_lecture];
      Inc(i);
      End;
If donnee=$AA Then Begin
                   Attendre_SB;
                   Port[Port_instructions]:=$D1; {Active le haut parleur}
                   End;

InitSB:=(donnee=$AA);
End;  { InitSB }

{--------------------------------------------------------------------}

Procedure Commander_sb(Taille:word); { Lancer la sortie DMA 8 Bits }

Begin
Attendre_sb;
Port[Port_instructions]:=$40;           { Commande de sortie DMA 8 Bit }
Attendre_sb;
Port[Port_instructions]:=Frequence_SB;  { Fr‚quence du sample          }
Attendre_sb;
Port[Port_instructions]:=$14;           { Commande Taille du sample    }
Dec(Taille);
Attendre_sb;
Port[Port_instructions]:=Word(Taille) AND $FF;         {partie basse de la taille}
Attendre_sb;
Port[Port_instructions]:=(Word(Taille) SHR 8) AND $FF; {partie haute de la taille}

End;  { Commander_sb }

{--------------------------------------------------------------------}

Procedure Activer_IRQ;     { Activer l'interruption }

VAR Donnee:Byte;

VAR Masque:Byte;

Begin
Donnee:=Port[$21];
Sauvegarde_Port_controleur:=Donnee;
Masque:=BYTE(NOT(1 SHL IRQ_SB));
Donnee:=Donnee AND Masque;
Port[$21]:=Donnee;
End; { Activer_IRQ }

{--------------------------------------------------------------------}

Procedure Desactiver_IRQ;

Begin
Port[$21]:=Sauvegarde_Port_controleur;
End;  { Desactiver_IRQ }

{--------------------------------------------------------------------}

Procedure Nouvelle_IRQ; Interrupt;

Begin
Fin_du_sample:=True;
Port[$20]:=$20;
End;

procedure Installer_IRQ(routine:pointer);  { D‚tourner l'interruption }

Begin
     inline(CLI);
     GetIntVec(IRQ_SB+8,vecteur_initial);
     SetIntVec(IRQ_SB+8,routine);
     inline(STI);
End;  { Installer_IRQ }

{--------------------------------------------------------------------}

procedure Restaurer_IRQ;

Begin
inline(CLI);
SetIntVec(IRQ_SB+8,vecteur_initial);
inline(STI);
End;  { Restaurer_IRQ }

{--------------------------------------------------------------------}

Procedure Init_DMA(Sample:Pointer;Taille:Longint);

Var

    Segment : Longint;
    Offset  : Longint;
    Adresse : Longint;
    Port_H  : Word;
    Port_L  : Word;
    i:byte;

Begin

{ Initialise le controleur DMA (Circuit 8237) }

Port[$0A] := $04+DMA_SB; { D‚sactive le canal DMA   }
Port[$0C] := $00;        { Efface le flip flop      }

Port[$0B] := $58+DMA_SB; { Type de transfert DMA    }

Segment:= seg(Sample^);
Offset := ofs(Sample^);
Adresse:= Segment SHL 4 + Offset;          { Calcul de l'adresse du tampon   }

Port_L:=DMA_SB SHL 1;                      { Port_L:=2*DMA_SB                }

Port[Page_DMA[DMA_SB]] := Adresse SHR 16 ; { Chargement page                 }
Port[Port_L] := Adresse AND $FF;           { Chargement partie basse adresse }
Port[Port_L] := (Adresse SHR 8);           { Chargement partie haute adresse }

Port_H:=Port_L+1;
Dec(Taille);

Port[Port_H]:=Word(Taille) AND $FF;         {Chargement partie basse de la taille}
Port[Port_H]:=(Word(Taille) SHR 8) AND $FF; {Chargement partie haute de la taille}

Port[$0A]:=DMA_SB;   { Active le canal DMA 1 }

End;  { Init_DMA }

{--------------------------------------------------------------------}

Procedure Affiche_erreur(Erreur:Byte);

Begin
Case Erreur of
 1:Writeln('Fichier non trouv‚ !');
 2:Writeln('Ce n''est pas un fichier VOC');
 3:Writeln('Version incorrecte (Version ',En_tete_voc.Version_entier,'.',
            En_tete_voc.Version_decimal,')');
 4:Writeln('La fr‚quence de ce fichier est trop grande pour une Sound',
            'Blaster');
 5:Writeln('La Taille de l''‚chantillon doit ˆtre inf‚rieure … 64000 octets');
  End;
End;  { Affiche_Erreur }

{--------------------------------------------------------------------}

Function Detecte_Erreur:Integer;

Var Erreur:Integer;

Begin
Erreur:=0;
If (En_tete_voc.Version_decimal<>10) OR (En_tete_voc.Version_entier<>1) Then
    Erreur:=3;
If Frequence_SB>212 Then Erreur:=4;
If Taille>64000 Then Erreur:=5;
With En_tete_voc do
     Begin
     If (Identificateur<>'Creative Voice File') OR (Octet_EOF<>26) Then
         Erreur:=2;
     End;
Detecte_Erreur:=Erreur;
End;  { Detecte_Erreur }

{--------------------------------------------------------------------}

Procedure Charge_VOC(Nom:String;VAR Erreur:Byte);

Var Fichier:File;
    Resultat:Integer;

Begin
{$I-}
Assign(Fichier,Nom);
Reset(Fichier,1);
{$I+}
Resultat:=IOresult;
If Resultat=0 then
   Begin
   Blockread(Fichier,En_tete_voc,Sizeof(En_tete_voc));
   Blockread(Fichier,En_tete_bloc,Sizeof(En_tete_bloc));
   Taille:=256*En_tete_bloc.Taille_h+En_tete_bloc.Taille_l;
   Taille:=Taille-2;
   Blockread(Fichier,Frequence_SB,1);
   Blockread(Fichier,Compression,1);

   Erreur:=Detecte_Erreur;
   If Erreur=0 Then Blockread(Fichier,Sample^,Taille);

   Close(Fichier);
   End
   Else
   Erreur:=1;

End; { Charge_VOC }

{--------------------------------------------------------------------}
{                     Programme principal                            }
{--------------------------------------------------------------------}

Begin

Writeln('Playvoc v1.0 Par Freddy V‚tel‚');
Writeln;
If Paramcount>=1 Then
  Begin
  Nom_fichier:=Paramstr(1);
  if Pos('.',Nom_fichier)=0 Then Nom_fichier:=Nom_fichier+'.VOC';
  Writeln('Charge le fichier ',Nom_fichier);
  If InitSB Then
  Begin
    Getmem(Sample,64000);
    Charge_voc(Nom_fichier,Erreur);
    If Erreur=0 then
       Begin
       Write('Taille: ',Taille,' Fr‚quence: ',ROUND(1000000/(256-Frequence_SB)));

       Activer_IRQ;
       Installer_IRQ(PTR(Seg(Nouvelle_IRQ),ofs(Nouvelle_IRQ)));
       Init_DMA(Sample,Taille);
       Fin_du_sample:=False;
       Commander_SB(Taille);
       Repeat Until Fin_du_sample OR Keypressed;
       If not Fin_du_sample Then Fin_du_sample:=InitSB;
       Restaurer_IRQ;
       Desactiver_IRQ;

       End
       Else Affiche_Erreur(Erreur);
    Freemem(Sample,64000)
  End
  Else Writeln('Carte Sound Blaster non trouv‚e');
End
Else Writeln('Utilisation: Playvoc Fichier[.VOC]');
Writeln;

End.
