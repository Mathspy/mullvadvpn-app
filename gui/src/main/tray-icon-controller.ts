import { exec as execAsync } from 'child_process';
import { nativeImage, NativeImage, Tray } from 'electron';
import path from 'path';
import { promisify } from 'util';
import KeyframeAnimation from './keyframe-animation';

const exec = promisify(execAsync);

export type TrayIconType = 'unsecured' | 'securing' | 'secured';

export default class TrayIconController {
  private animation?: KeyframeAnimation;
  private iconImages: NativeImage[] = [];

  constructor(
    private tray: Tray,
    private iconTypeValue: TrayIconType,
    private useMonochromaticIconValue: boolean,
  ) {}

  public async init() {
    await this.loadImages();

    const initialFrame = this.targetFrame();
    const animation = new KeyframeAnimation();
    animation.speed = 100;
    animation.onFrame = (frameNumber) => this.tray.setImage(this.iconImages[frameNumber]);
    animation.play({ start: initialFrame, end: initialFrame });

    this.animation = animation;
  }

  public dispose() {
    if (this.animation) {
      this.animation.stop();
      this.animation = undefined;
    }
  }

  get iconType(): TrayIconType {
    return this.iconTypeValue;
  }

  public async reloadImages() {
    await this.loadImages();

    if (this.animation && !this.animation.isRunning) {
      this.animation.play({ end: this.targetFrame() });
    }
  }

  public async setUseMonochromaticIcon(useMonochromaticIcon: boolean) {
    this.useMonochromaticIconValue = useMonochromaticIcon;
    await this.reloadImages();
  }

  public animateToIcon(type: TrayIconType) {
    if (this.iconTypeValue === type || !this.animation) {
      return;
    }

    this.iconTypeValue = type;

    const animation = this.animation;
    const frame = this.targetFrame();

    animation.play({ end: frame });
  }

  private async loadImages() {
    const frames = Array.from({ length: 10 }, (_, i) => i + 1);
    this.iconImages = await Promise.all(
      frames.map(async (frame) => nativeImage.createFromPath(await this.getImagePath(frame))),
    );
  }

  private async getImagePath(frame: number) {
    const basePath = path.resolve(path.join(__dirname, '../../assets/images/menubar icons'));
    const extension = process.platform === 'win32' ? 'ico' : 'png';
    let suffix = '';
    if (this.useMonochromaticIconValue) {
      suffix = await this.monochromaticFileNameSuffix();
    }

    return path.join(basePath, process.platform, `lock-${frame}${suffix}.${extension}`);
  }

  private async monochromaticFileNameSuffix() {
    switch (process.platform) {
      case 'darwin':
        return 'Template';
      case 'win32': {
        try {
          // This registry entry contains information about the tray background color. This is
          // needed to decide between white and black icons.
          const { stdout, stderr } = await exec(
            'reg query HKEY_CURRENT_USER\\Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize\\ /v SystemUsesLightTheme',
          );

          if (!stderr && stdout) {
            // Split the output into rows
            const rows = stdout.split('\n');
            // Select the row that contains the registry entry result
            const resultRow = rows.find((row) => row.includes('SystemUsesLightTheme'))?.trim();
            // Split the row into words
            const resultRowWords = resultRow?.split(' ').filter((word) => word !== '');
            // Grab value which is last word on the result row
            const value = resultRowWords && resultRowWords[resultRowWords.length - 1];

            if (value) {
              const parsedValue = parseInt(value);
              return parsedValue === 1 ? '_black' : '_white';
            }
          }

          return '_white';
        } catch {
          return '_white';
        }
      }
      case 'linux':
      default:
        return '_white';
    }
  }

  private targetFrame(): number {
    switch (this.iconTypeValue) {
      case 'unsecured':
        return 0;
      case 'securing':
        return 9;
      case 'secured':
        return 8;
    }
  }
}
